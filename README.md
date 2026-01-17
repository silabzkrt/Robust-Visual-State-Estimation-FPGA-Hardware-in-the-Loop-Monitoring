# Robust Visual State Estimation & FPGA Hardware-in-the-Loop Monitoring

## 1. Abstract
This project presents a robust object tracking architecture integrating Computer Vision, Adaptive State Estimation, and FPGA-based Hardware-in-the-Loop (HIL) monitoring. The system addresses the challenge of tracking maneuvering targets under sensor occlusion and noise. It implements an Adaptive Kalman Filter (AKF) with dynamic process noise scaling based on Normalized Innovation Squared (NIS) statistics. Furthermore, a Xilinx Artix-7 FPGA (Basys 3) functions as a dedicated safety monitor, visualizing real-time kinematic metrics (Velocity, Acceleration, Displacement) via UART communication.


## 2. Research Contributions
* **Adaptive State Estimation:** Implementation of an Innovation-based Adaptive Kalman Filter that dynamically inflates the process noise covariance ($Q$) upon detecting high NIS (Mahalanobis distance). This significantly reduces lag during non-linear maneuvers compared to standard filters.
* **Occlusion Recovery:** Development of a trajectory prediction algorithm capable of "coasting" through data loss events (occlusions). Uncertainty is visualized via covariance ellipses, demonstrating how confidence intervals expand during sensor blackout.
* **Hardware-in-the-Loop (HIL):** Utilization of an FPGA as an independent "Watchdog" unit. It decouples safety monitoring from the primary computational node, ensuring that physical limit violations (e.g., excessive acceleration) are detected at the hardware level.



## 3. System Architecture
The system consists of three distinct modules:

1.  **Vision Node (Python/OpenCV):** Captures raw video frames, segments the target (orange ball) in HSV color space, and logs noisy coordinate data with precise timestamps.
   * Captures raw video frames and segments the target (orange ball) in HSV color space.
   * Applies morphological operations (Erosion/Dilation) for noise reduction.
   * Logs noisy coordinate data with precise timestamps.
3.  **Estimation Node (MATLAB):** * Parses raw logs.
    * Runs dual filters (Standard vs. Adaptive) for performance comparison.
    * Calculates NIS statistics for consistency checking ($\chi^2$ test).
4.  **Hardware Monitor (SystemVerilog on Basys 3):**
     * Parses UART packets via a custom Finite State Machine (FSM).
   * Calculates and visualizes Odometer (Distance), Velocity, and G-Force (Acceleration) on the 7-segment display based on switch configuration
    * Receives kinematic data via UART (9600 Baud).
    * **Switch 0:** Displays Total Displacement (Odometer).
    * **Switch 1:** Displays Velocity Magnitude.
    * **Switch 2:** Displays Instantaneous Acceleration (G-Force).
    * **LED Array:** visualizes magnitude intensity.

## 4. File Structure & Descriptions

### A. Hardware (FPGA / SystemVerilog)
* **`top_module.sv`**: The main entry point. Implements the UART packet parser (State Machine), the kinematic dashboard logic, and drives the 7-segment display.
* **`uart_rx.sv`**: A custom UART receiver module operating at 9600 baud (100MHz clock). It handles the physical layer communication between PC and FPGA.
* **`seven_seg_driver.sv`**: Multiplexing driver for the 4-digit 7-segment display to show Hexadecimal values of the selected metric.
* **`cons.xdc`**: Xilinx Constraints File mapping logic ports to physical pins (Switches, LEDs, USB-RS232).

### B. Vision (Python)
* **`track_object.py`**: A computer vision script using OpenCV. It applies morphological operations (Erosion/Dilation) to reduce noise, detects the object centroid, and logs `[Timestamp, X, Y, Radius]` to a CSV file. It handles "NaN" logging during occlusions.

### C. Analysis (MATLAB)
* **`research_comparison.m`**: The core research script. It compares a Standard Kalman Filter against the Adaptive version. It generates plots for Trajectory, Velocity, and Filter Consistency (NIS) to prove the algorithm's robustness.
* **`replay_and_hardware.m`**: A HIL interface script. It replays the recorded dataset, calculates real-time physics (Velocity/Accel), and transmits packets `[Header, Dist, Vel, Acc]` to the FPGA over Serial (COM Port).

## 5. Experimental Results

## 6. How to Run

1.  **Hardware Setup:** Connect Basys 3 via USB. Program with the generated bitstream.
2.  **Data Acquisition:** Run `track_object.py`. Move an orange object in front of the camera. Introduce occlusions (hiding the object) to test robustness. Press 'q' to stop.
3.  **Analysis:** Run `research_comparison.m` in MATLAB to generate performance graphs.
4.  **HIL Demo:** Run `replay_and_hardware.m`. Observe the Basys 3 board:
    * Toggle **SW0** to see Distance.
    * Toggle **SW1** to see Speed.
    * Toggle **SW2** to see Acceleration.
