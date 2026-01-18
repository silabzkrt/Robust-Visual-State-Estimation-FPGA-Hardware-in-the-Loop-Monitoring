import cv2
import numpy as np
import time
import csv
import os
from datetime import datetime


def track_orange_ball():
    """
    Track an orange ball across the screen and record coordinates
    """
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("Error: Could not open camera.")
        return
    
    # Define the orange color range in HSV 
    # you may change it according to the color you use
    lower_orange = np.array([5, 100, 100])
    upper_orange = np.array([25, 255, 255])
    
    # Create CSV file to store coordinates
    # 1. Get the folder where this python script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # 2. Create the full path for the CSV
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_filename = f"ball_coordinates_{timestamp}.csv"
    full_save_path = os.path.join(script_dir, csv_filename)

    print(f"DEBUG: FORCE SAVING TO -> {full_save_path}")
    
    with open(csv_filename, 'w', newline='') as csvfile:
        csv_writer = csv.writer(csvfile)
        csv_writer.writerow(['Timestamp', 'X', 'Y', 'Radius'])
        
        print(f"Tracking orange ball. Press 'q' to quit.")
        print(f"Saving coordinates to: {csv_filename}")
        
        last_record_time = time.time()
        record_interval = 0.01 
        
        while True:
            ret, frame = cap.read()
            
            if not ret:
                print("Error: Could not read frame.")
                break
            
            hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
            mask = cv2.inRange(hsv, lower_orange, upper_orange)
            kernel = np.ones((5, 5), np.uint8)
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
            
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, 
                                           cv2.CHAIN_APPROX_SIMPLE)
            
            current_time = time.time()
            
            if contours:
                largest_contour = max(contours, key=cv2.contourArea)
                
                ((x, y), radius) = cv2.minEnclosingCircle(largest_contour)
                
                if radius > 10:
                    cv2.circle(frame, (int(x), int(y)), int(radius), 
                               (0, 255, 0), 2)
                    cv2.circle(frame, (int(x), int(y)), 5, (0, 0, 255), -1)
                    
                    coord_text = f"X: {int(x)}, Y: {int(y)}"
                    cv2.putText(frame, coord_text, (
                        int(x) - 50, int(y - radius - 10)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, 
                                (255, 255, 255), 2)
                    
                    if current_time - last_record_time >= record_interval:
                        timestamp_str = str(time.time()) 
                        csv_writer.writerow([timestamp_str, int(x), int(y), 
                                             int(radius)])
                        csvfile.flush()  
                        last_record_time = current_time
                        print(f"Recorded: {coord_text}, Radius: {int(radius)}")
            
                # Display the mask and original frame
                cv2.imshow('Orange Ball Tracking', frame)
                cv2.imshow('Mask', mask) 

                # This updates the window. Without it, the windows will freeze or stay black.
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

    cap.release()
    cv2.destroyAllWindows()
    print(f"\nTracking completed. Coordinates saved to: {csv_filename}")


if __name__ == "__main__":
    track_orange_ball()
