/* 3D-particles_nucleus developed by Laura Salavessa (May 2025) and used in Benito-Martinez, Salavessa, et al. (2025) NCB.
 * The macro will perform a segmentation of nuclei based on Channel 5 (Nuc) and then measure foci/particles on Channel 2.
 * It will save a zip file with the nuclei ROIs, intermediate segmentation images, an overlay image of Ch2 and detected foci,
 * and the csv files of foci results (morphological features and intensity based on the original image), as well as Ch2 nuclei MFI.
 * REQUIREMENTS: updated 3DSuite and IJPB (Morpholib) plugins!
 */
 
run("Close All");
run("Clear Results");
roiManager("reset");

newChannelArrangement = "12345"; // new order for channels, make sure foci/particles are in Ch2 and nuclei in Ch5

// Asks the user to open an image
path = File.openDialog("Select an image to analyze");
if (path == "") exit("No file selected");
run("Bio-Formats Importer", "open=[" + path + "] color_mode=Composite rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
title = getTitle();
dir = File.getParent(path);
results_dir = dir + File.separator + "Results";
File.makeDirectory(results_dir); // create a results folder

run("Arrange Channels...", "new="+newChannelArrangement); // change channel order
getDimensions(width, height, channels, slices, frames);

run("Duplicate...", "title=Visualization duplicate");
waitForUser("Look at the image to choose the slices to keep");

// Dialog box to ask the slices to keep using a Visualization duplicate to avoid that B&C changes affect segmentation later
Dialog.create("Z-slices to keep");
Dialog.addMessage("Enter the slices you want to study, between 1 and "+slices);
Dialog.addNumber("First slice", 1);
Dialog.addNumber("Last slice", slices);
wait(100); // 100 milliseconds delay otherwise the stupid dialog box bugs
Dialog.show();
first_slice = Dialog.getNumber();
last_slice = Dialog.getNumber();

close("Visualization");

// Duplicates the image with the slices to keep
selectWindow(title);

// Ask the user to input voxel depth (Z spacing in microns) and set voxel dimensions
getVoxelSize(voxelWidth, voxelHeight, voxelDepth, unit);
voxelZ = getNumber("Enter Z-step size (voxel depth) in microns:", 0.2);
run("Properties...", "channels=" + channels + " slices=" + slices + " frames=" + frames + " pixel_width=" + voxelWidth + " pixel_height=" + voxelHeight + " voxel_depth=" + voxelZ);

run("Select None");
run("Duplicate...", "title=title-2 duplicate slices="+first_slice+"-"+last_slice);
run("Select None");

close(title); // closes first opened image

// Get Ch5 (Nuclei) and Ch2 (gH2AX) images
selectImage("title-2");
run("Duplicate...", "duplicate channels=5 duplicate");
rename("Nuc");
selectImage("title-2");
run("Duplicate...", "duplicate channels=2 duplicate");
rename("Ch2");
selectImage("title-2");
close;

// Create Nuc mask and ROIs
selectImage("Nuc");
run("Z Project...", "projection=[Max Intensity]");
run("Duplicate...", "title=tempMAX_Nuc duplicate");
selectImage("tempMAX_Nuc");
run("Median...", "radius=2");
run("Gaussian Blur...", "sigma=1");
setOption("ScaleConversions", true);
run("8-bit");
run("Auto Threshold", "method=Minimum dark"); // adjust method to best fit the labelling used for cell segmentation
run("Convert to Mask");
run("Analyze Particles...", "size=50.00-400.00 show=Overlay add"); // adjust size according to nuclei size
nbNuc = roiManager("count");

waitForUser("Remove the cells you don't want to analyze from the ROI manager");

// Rename the Nuclei ROIs
nbNuc = roiManager("count");
for (i = 0; i < nbNuc; i++) {
    roiManager("select", i);
    roiManager("rename", "Nuc" + (i+1));
}

close("Nuc");
close("MAX_Nuc");
close("tempMAX_Nuc");

print("Number of ROIs: " + roiManager("count"));

// Save Nuc ROIs in a zip file
roiPath = results_dir + File.separator + title + "_ROIs.zip";
roiManager("save", roiPath);

// Measure fluo in Ch2 nuclei
selectImage("Ch2");
run("Z Project...", "projection=[Max Intensity]");
rename("Ch2_MAX");

waitForUser("Draw a square ROI on Ch2_MAX for background, then click OK."); // Ask the user to draw a background ROI
roiManager("Add");
count = roiManager("count");
bckg = count - 1; // index of the background ROI
roiManager("Select", bckg);
roiManager("Rename", "Background");

run("Set Measurements...", "area mean min integrated display redirect=None decimal=5");
RoiManager.useNamesAsLabels(true);
RoiManager.associateROIsWithSlices(false);
roiManager("Deselect");
for (i = 0; i < count; i++) { // Measure intensity in all ROIs
    roiManager("select", i);
    roiManager("Measure");
}

resultsPath = results_dir + File.separator + title + "_Ch2_MFI.csv"; // Save results table
saveAs("Results", resultsPath);

roiManager("Select", bckg); // Delete the background ROI so it's not considered in future processing
roiManager("Delete");
close("Ch2_MAX");
run("Clear Results");

// Processing of Ch2 image
selectImage("Ch2");
run("Select None");
run("Duplicate...", "title=temp_Ch2 duplicate"); // create a temporary image that will be processed
selectImage("temp_Ch2");
run("8-bit");
run("Grays");
run("Enhance Contrast...", "saturated=0 normalize process_all use");
run("Subtract Background...", "rolling=50");
run("Gaussian Blur 3D...", "x=0.3 y=0.3 z=0.3");

// Segmentation by threshold
selectImage("temp_Ch2");
run("Duplicate...", "title=binary_Ch2 duplicate"); // create an image that will be converted to binary
run("Auto Local Threshold", "method=Median radius=15 parameter_1=-60 parameter_2=0 white stack"); // decrease parameter 1 to get more puncta
//run("Dilate", "stack"); // shrinks the size of the detection, if it is too strict and particles get too small remove it
rename("binary_Ch2");

// Label the binary image as separate 3D objects to add to 3D ROI Manager
run("Connected Components Labeling", "connectivity=26 type=[16 bits]");
rename("objects_Ch2");

// Analyze Ch2 particles in cells by looping through each cell ROI
for (n = 0; n < nbNuc; n++) {
    objNuc = "Obj-Nuc" + (n+1);
    roiName = "Nuc" + (n+1);
    binNuc = "binNuc" + (n+1);
    
    selectImage("objects_Ch2");
    roiManager("select", n);
    run("Duplicate...", "title="+objNuc+" duplicate use"); // duplicates one cell at a time with its objects
    
    // Check if this cell contains any objects (count particles) - safecheck to prevent bugging of 3D Manager when there are no objects
    selectImage("binary_Ch2");
    roiManager("select", n);
    run("Duplicate...", "title="+binNuc+" duplicate use");
    run("Z Project...", "projection=[Max Intensity]");
    tempProj = "Max_" + objNuc;
    rename(tempProj);
    run("Restore Selection");
    run("Analyze Particles...", "size=5-Infinity pixel display clear"); // adjust min size of particles
    nObjects = nResults;
    run("Clear Results");
    
    if (nObjects == 0) { // if the number of particles detected is 0 skip that cell
        print("Skipping " + roiName + " - no objects detected");
        close(tempProj);
        close(objNuc);
        close(binNuc);
        continue; // Skip to next cell
    }
    close(tempProj);
    close(binNuc);
    
    selectImage("Ch2");
    roiManager("select", n);
    run("Duplicate...", "title="+roiName+" duplicate"); // duplicates one cell at a time from the original image
   
    run("3D Manager");
    selectImage(objNuc);
    Ext.Manager3D_AddImage; // add the objects image
    selectImage(roiName);
    Ext.Manager3D_SelectAll;
    Ext.Manager3D_Quantif; // quantify intensity on the original image
    Ext.Manager3D_SaveResult("Q", results_dir + File.separator + title + "_" + roiName + "_3Dfoci-intens.csv");
    Ext.Manager3D_CloseResult("Q");
    selectImage(roiName);
    Ext.Manager3D_Measure; // quantify morphological measurements on the original image
    Ext.Manager3D_SaveResult("M", results_dir + File.separator + title + "_" + roiName + "_3Dfoci-morph.csv");
    Ext.Manager3D_CloseResult("M");
    Ext.Manager3D_SelectAll;
    Ext.Manager3D_Delete;
    close(objNuc);
    close(roiName);

}

// Function to merge CSV files with Cells ID
function mergeFiles(pattern, outputName) { // the pattern and outputName are defined when the function is called, in this case at the end
    fileList = getFileList(results_dir);
    header = "";
    mergedData = "";
    count = 0;
    
    for (i=0; i<fileList.length; i++) {
        if (indexOf(fileList[i], pattern) >= 0 && indexOf(fileList[i], title) >= 0) { // checks if the files in the directory contain the pattern and the image title
            // Find the position where "Nuc" appears in filename
            NucPos = indexOf(fileList[i], "Nuc");
            if (NucPos == -1) continue; // Skip if "Nuc" is not found
            tempStr = substring(fileList[i], NucPos); // get everything from "Nuc" to the next underscore
            NucID = replace(tempStr, "_3Dfoci-.*", "");
            
            // Read file content
            path = results_dir + File.separator + fileList[i];
            data = File.openAsString(path);
            lines = split(data, "\n");
            
            // Process header (only for first file)
            if (count == 0 && lines.length > 0) {
                header = lines[0] + ",Nuc";
            }
            
            // Process data lines
            for (j=1; j<lines.length; j++) {
                if (lengthOf(lines[j]) > 0) {
                    mergedData = mergedData + lines[j] + "," + NucID + "\n";
                }
            }
            count++;
        }
    }
    
    if (count > 0) {
        // Create and save the merged file
        output = header + "\n" + mergedData;
        File.saveString(output, results_dir + File.separator + outputName);
        
        // Delete individual Cells files after merging
        for (i=0; i<fileList.length; i++) {
            if (indexOf(fileList[i], pattern) >= 0 && indexOf(fileList[i], title) >= 0) {
                File.delete(results_dir + File.separator + fileList[i]);
            }
        }
    }
}

// Merge the files after processing all Cells
mergeFiles("_3Dfoci-intens.csv", title + "_ALL_3Dfoci-intens.csv");
mergeFiles("_3Dfoci-morph.csv", title + "_ALL_3Dfoci-morph.csv");

// Save the binary image
selectImage("binary_Ch2");
saveAs("Tiff", results_dir + File.separator + title + "_threshold.tif");
close("binary_Ch2");

// Create a merge overlay of detected 3D objects and original image
selectImage("Ch2");
run("Grays");
run("Invert LUT");

selectImage("objects_Ch2");
run("Select None");
run("Merge Channels...", "c1=objects_Ch2 c4=Ch2 create keep");
saveAs("Tiff", results_dir + File.separator + title + "_overlay.tif");

// Save the objects image
selectImage("objects_Ch2");
saveAs("Tiff", results_dir + File.separator + title + "_objects.tif");

close("Statistics");
close("Summary");

waitForUser("Analysis complete.");
