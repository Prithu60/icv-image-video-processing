# Image and Video Processing in MATLAB

MATLAB scripts that find and correct faults in six photographs, then detect and track moving objects in a 240-frame image sequence and two CCTV videos. Each fault is diagnosed first with histograms, edge maps or simple numeric measures, then several methods are compared and the best one is chosen on evidence.

Built for the Intelligent Computer Vision module of my BSc (Hons) Computing degree at The British College. The coursework images and videos came from the module, so they are not included in this repo.

## Image correction

| Script | Fault | Methods compared | Chosen result |
|---|---|---|---|
| `Image1_analysis.m` | Strong green colour cast | Gray World, White Patch (99th percentile), Soft Gray World | Soft Gray World (blend strength 0.85). Gray World over-corrected to magenta and White Patch barely changed the image. Channel means moved from 42.7 / 69.0 / 32.5 to about 47 / 49 / 41. |
| `Image2_analysis.m` | Out-of-focus blur | Unsharp masking, Lucy-Richardson deconvolution | Deconvolution followed by unsharp masking, with sharpness measured by Laplacian variance. |
| `Image3_analysis.m` | Impulse and Gaussian noise | Median filter, Wiener filter, both combined | Median then Wiener. Noise estimate fell from 37.5 to 10.9. |
| `Image4_analysis.m` | Underexposure | Histogram equalisation, CLAHE, gamma correction | Gamma correction, which brightened smoothly without amplifying noise or adding haze. |
| `Image5_analysis.m` | Motion blur on the subject only | Lucy-Richardson and Wiener deconvolution, with a motion PSF | Lucy-Richardson applied through a feathered mask, so only the blurred subject is sharpened. Wiener produced ringing across the sharp background. |
| `Image6_analysis.m` | Haze, yellow cast and low contrast | `imreducehaze`, decorrelation stretch, haze reduction plus CLAHE | `imreducehaze` followed by CLAHE. |

## Sequence and video tracking

| Script | Task | Approach | Result |
|---|---|---|---|
| `FrameSeq1.m` | Track a moving Vespa in 240 dark night-time frames | Colour threshold on the red brake light in a restricted region of interest, morphological clean-up, moving-median smoothing of the trajectory | Brake light found in 219 of 240 frames (91.2%) |
| `Video1.m` | Detect a reversing van in a 22-frame CCTV clip | Frame differencing against first-frame background subtraction in Lab colour space | Background subtraction detected the van in 21 of 22 frames (95.5%), against 15 of 22 (68.2%) for frame differencing. The first frame has no foreground by definition. |
| `Video2.m` | Detect and track a car approaching at night (70 frames) | CLAHE plus gamma correction, then a joint brightness-and-motion mask with adaptive thresholds | Detected in all 70 frames (100%) |

## Run it

1. Open the script in MATLAB with the Image Processing Toolbox installed.
2. Put the matching input file next to the script (for example `Image1.jpg`, `video1.avi`, or the `FrameSeq1` folder of frames). The inputs are coursework files and are not included in this repo.
3. Run the script. Each script clears the workspace, shows figures step by step and prints its numbers in the Command Window.

`Image2_analysis.m` reads the file as `Imag2.JPG`, which was the file name on my copy. Change it to match yours.

The video scripts write annotated output videos such as `video1_tracked.avi` to the working folder.

## Limitations

- Thresholds, such as the red and green/blue limits for the brake light and the percentile limits for the headlights, were tuned by hand on these clips and may not carry over to other footage.
- The point-spread functions used for deblurring are estimates, so the deblurring gains are modest.
- Detection rates count the frames in which a method produced a detection. They are not measured against labelled ground truth.

## Author

Prithu Adhikari (Prithu60)
