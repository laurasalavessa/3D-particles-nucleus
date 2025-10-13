# 3D γH2AX Foci Detection and Quantification Macro (3D-particles-nucleus.ijm)

**Overview**

The following code was developed in ImageJ/Fiji software to
automatically detect γH2AX nuclear foci across z-stack images. It
performs 3D segmentation of nuclei and foci, quantifies their number,
fluorescence intensity, and morphological features per cell. Results are
exported as .csv files for further processing.

The macro was developed for the analysis of UVB-irradiated primary human
keratinocytes, immunolabeled with anti-phospho-Histone H2A.X, and using
confocal images with 5 channels (as in Benito-Martinez S., Salavessa L.,
*et al*. NCB 2025). However, it can be adapted for other cell types,
markers with nuclear foci, or variable channels.

**Installation / Requirements**

<u>Software</u>: Fiji (ImageJ), the macro was developed on version
2.16.0/1.54p.

<u>Plugins</u>: The macro requires an updated 3D ImageJ Suite (for 3D
ROI Manager and connected components labeling,
<https://imagej.net/plugins/3d-imagej-suite/>) and MorphoLibJ (for
morphology measurements, <https://imagej.net/plugins/morpholibj>).

**Workflow Summary**

1.  <u>Nucleus segmentation</u>

- A maximum intensity projection of the nuclear channel (Channel 5,
  “Nuc”) is done, smoothed, and thresholded to generate binary nuclear
  masks.

- Nuclei within a defined size range are identified using Analyze
  Particles, and each is saved as a region of interest (ROI).

2.  <u>ROI curation</u>

- The user is prompted to manually remove unwanted or poorly segmented
  nuclei from the ROI Manager before continuing. The user can also
  manually draw nuclei and add them to the ROI manager.

- The curated set of ROIs is saved as a .zip file.

3.  <u>Measurement of nuclear fluorescence intensity (Channel 2)</u>

- A maximum intensity projection of the foci channel (Channel 2, “Ch2”;
  e.g., γH2AX) is done and the user is prompted to manually select a
  representative background region.

- The mean background intensity is measured and recorded.

- The MFI of each nucleus ROI is measured on the same image and the
  resulting values were saved as a .csv file (\*\_Ch2_MFI.csv) for
  downstream normalization and analysis.

4.  <u>Channel preprocessing (foci channel)</u>

- The foci channel (Ch2; e.g., γH2AX) is duplicated, converted to 8-bit
  grayscale, contrast-enhanced, and background-subtracted. A light 3D
  Gaussian blur is applied to smooth noise.

5.  <u>Foci segmentation</u>

- A local threshold (median, radius = 15) is applied to create a binary
  mask of foci.

- Connected component labeling (26-connectivity) identifies individual
  3D objects.

6.  <u>Per-cell analysis</u>

- For each nucleus ROI, corresponding sub-stacks of Ch2 are extracted.
  Only cells containing detectable foci are analyzed further (number of
  foci \>0).

- Using the 3D ROI Manager, the macro quantifies: foci fluorescence
  intensity (quantification on the original image); foci morphological
  parameters (volume, shape, etc.).

- Results are exported as .csv files, which are generated per nucleus
  and then pulled together, resulting in two files per image with all
  analyzed nuclei (\*\_3Dfoci-intens.csv and \*\_3Dfoci-morph.csv).

7.  <u>Overlay generation</u>

- The segmented 3D foci are merged with the original foci channel
  (inverted LUT) to produce a visual overlay, saved as a multi-channel
  .tif for inspection.

- Additionally, intermediate segmentation outputs are saved to
  facilitate quality control. The macro automatically saves both the
  binary thresholded image (\*\_threshold.tif) and the labeled 3D
  objects image (\*\_objects.tif). These files allow users to visually
  verify the segmentation accuracy before downstream quantification.

**How to use**

1.  Download the macro (3D-particles-nucleus.ijm) from this repository.

2.  Open it in Fiji via Plugins \> Macros \> Edit.

3.  Place your image files in a single directory (output files will be
    saved here in a “Results” folder).

4.  Run the macro — it will prompt you to:

- Select the image to analyze.

- Check channel order: by default, the macro assumes the nuclear channel
  is in channel 5 and the particle/foci channel (e.g., γH2AX) is in
  channel 2. Adjust channel order in line 14. If this step is not
  needed, comment line 25.

- Select the slices (z-range) to analyze.

- Set the voxel depth according to your image metadata.

5.  Channel 5 (nucleus, “Nuc”) and channel 2 (foci/particles, “Ch2”) are
    duplicated and Nuc channel is pre-processed for segmentation.

6.  Review the detected nuclei by removing unwanted or poorly segmented
    nuclei. If needed, manually draw nuclei and add them to the ROI
    Manager.

7.  Ch2 nuclear MFI is measured on a maximum intensity projection. You
    will be prompted to manually draw a square ROI in the background
    region. Note that this step measures the MFI of the entire projected
    nuclei, not the individual foci.

8.  A duplicate image of Ch2 is used for threshold-based segmentation
    (see *Notes and Tips* below for guidance on parameter adjustement).
    The “Connected Components Labeling” function (26-connectivity)
    identifies individual 3D foci.

9.  3D particle quantification (fluorescence intensity and morphological
    measurements) is performed by 3D ROI Manager on the original Ch2
    images, each nucleus individually.

10. All measurement .csv files, merged overlay .tif images, and
    intermediate segmentation files are automatically saved using the
    original image filename (see *Output Files* below for details).

**Log Messages**

At the end of each image analysis, the Fiji Log window displays progress
messages summarizing the results for that image. Typical output includes
the number of detected 3D objects (foci) and the paths of the saved
results files.

If a nucleus contains no detectable foci, the log will indicate that it
has been skipped.

**Output Files**

| File type             | Description                                     |
|-----------------------|-------------------------------------------------|
| \*\_ROIs.zip          | Final set of nuclear ROIs                       |
| \*\_Ch2_MFI.csv       | Ch2 mean fluorescence intensity per nucleus     |
| \*\_3Dfoci-intens.csv | Foci intensity measurements per nucleus         |
| \*\_3Dfoci-morph.csv  | Foci morphology measurements per nucleus        |
| \*\_overlay.tif       | Merged overlay of foci and original image       |
| \*\_threshold.tif     | Binary (thresholded) Ch2 image of detected foci |
| \*\_objects.tif       | 3D labeled foci image used for quantification   |

**Notes and Tips**

- For nuclei segmentation, adjust thresholding parameters (Auto
  Threshold method, line 76) and particle detection parameters (Analyze
  Particles size, line 78).

- For Ch2 segmentation, adjust Auto Local Threshold method, radius, and
  parameter_1 (line 143) to fit your staining quality. If foci are too
  small or fragmented, increase radius or decrease parameter_1. An
  optional dilation step (line 144) is included in the macro but
  commented out by default. This operation slightly expands detected
  objects and can be enabled if the segmentation is too restrictive or
  if the identified foci appear fragmented or undersized due to image
  noise or low signal intensity.

- For consistent results, use identical microscope settings across all
  conditions.

**Citation**

If you use or adapt this macro, please cite:

Benito-Martinez S., Salavessa L. et al., “Keratin intermediate filaments
mechanically position melanin pigments for genome photoprotection” NCB
(2025). [GitHub Repository Link]
