# -*- coding: utf-8 -*-
"""
Created on Mon Apr 27 16:14:31 2020

@author:    Philipp
            philipp.matten@meduniwien.ac.at

"""

# Global imports
import os
import sys
import cv2
import glob 
from tqdm import tqdm
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image  
from pathlib import Path
from tensorflow import keras

# Custom imports
import BackendFunctions as Backend
        
# =============================================================================
# Functions for inference, i.e. apply prediction on raw scans
# =============================================================================
class AutoSegmentation() :
    
    def __init__(self, net_dims, raw_dims, output_dims) :
        self.net_dims = net_dims
        self.raw_dims = raw_dims
        self.output_dims = output_dims  
        
    def load_data_from_folder(self, path, is_user_select_measurement_path=False) :
        """
        Primitive to load *.bmp-files of OCT b-Scans generated by ZEISS RESCAN
        """                
        if is_user_select_measurement_path :    
            path = Backend.clean_path_selection('Please select data for segmentation')
        if not Backend.is_ignore_segmented_dirs(path) :
            return None, path
        # check if path contains images
        assert any(fname.endswith('.bmp') for fname in os.listdir(path)), f"Directory {path} [DOES NOT CONTAIN ANY IMAGES] / *.BMP-files!"
        scan_list = glob.glob(os.path.join(path, "*.bmp"))
        # sort list after b-Scan #'s in image file names
        scan_list.sort(key=lambda f: int(''.join(filter(str.isdigit, f))))
        # Load (ONLY) b-Scans (with size = IMG_HEIGHT x IMG_WIDTH)
        # -> to avoid loading thumnail images
        scans = [np.asarray(Image.open(infile)) for infile in tqdm(scan_list) if np.shape(np.asarray(Image.open(infile))) == (self.raw_dims[0],self.raw_dims[1])]
        if scans is not None :
            return np.dstack(scans), path
        else : 
            return scans, path 
        
    def resize_images_without_interp(self, images, out_dims) :
        """
        Primitive to reshape image data stack and return as a 3D numpy-array
        """
        assert images.ndim == 3, "[IMAGE RESIZING ERROR] Wrong dimensionality of image data!"
        in_dims = np.shape(images)
        #print(f"Reshaping images from {in_dims} to {out_dims}...")
        images = [cv2.resize(images[:,:,i], 
                             (out_dims[0], out_dims[1]), 
                             interpolation = cv2.INTER_AREA) for i in range(in_dims[2])]
        return np.dstack(images)
        
    def apply_trained_net(self, scans, threshold, is_fixed_path_to_network=True) :
        """
        Predict and display segmented b-Scans -> Display to user
        """
        assert scans.ndim == 3, "[PREDICTION ERROR - IMAGE SIZE] - please check image data!"
        scans = self.resize_images_without_interp(scans, (self.net_dims[0], self.net_dims[1], scans.shape[2]))
        n_scans = np.shape(scans)[2]
        if is_fixed_path_to_network :
            path = r'/home/zeiss/Documents/Segmentation_AnteriorSegment/Networks/bestNetwork_9910_0.15_6_11epochs_512x256'
        else :
            path = Backend.clean_file_selection('Please select file with trained net for [AUTO-SEGMENTATION]')
        model = keras.models.load_model(path)
        predictions = []
        for scan in range(n_scans) :
            predictions.append(model.predict(np.expand_dims(np.expand_dims(scans[:,:,scan], axis=0), 
                                                            axis=-1), verbose=1))
        predictions = np.concatenate(predictions)
        #Threshold the masks for area-prediction
        masks = (predictions > threshold).astype(np.uint8)
        masks = np.moveaxis(masks, 0, -1)
        
        return masks
    
    def check_predicted_masks(self, scans, masks, path, alpha=0.6, is_apply_filter=False) :
        """
        Sort and check if automatically segmented b-Scans were segmented correctly
        --> Input images dimensionality = [h,w,ch,num] (reshaping in function)        
        """
        beta = 1-alpha
        masks = np.moveaxis(masks, 2, -1)
        path_good = os.path.join(path, 'CorrectScans')
        Path(path_good).mkdir(parents=True, exist_ok=True)
        path_bad = os.path.join(path, 'IncorrectScans')
        Path(path_bad).mkdir(parents=True, exist_ok=True)
        idx = Backend.find_max_idx(path_good, path_bad)
        print("Created paths for sorting!")
        print("Please review automatically segmented images...")
        scans = self.resize_images_without_interp(scans, self.output_dims)
        cornea = self.resize_images_without_interp(masks[:,:,:,0], self.output_dims)
        ovd = self.resize_images_without_interp(masks[:,:,:,1], self.output_dims)
        for im in range(idx, np.shape(scans)[2]) :            
            good_img_file = os.path.join(path_good, f'{im:03}' + '.bmp')
            bad_img_file = os.path.join(path_bad, f'{im:03}' + '.bmp')
            current_img = np.add(cornea[:,:,im]*255, ovd[:,:,im]*127)
            disp_img = cv2.addWeighted(scans[:,:,im], alpha, current_img, beta, 0)
            cv2.imshow(f"Predicted BACKGROUND-mask on original B-Scan No.{im} - left hand side = overlayed Cornea and OVD boundary - right hand side = background",
                       cv2.resize(disp_img, (450, 900), interpolation = cv2.INTER_AREA))
            key = cv2.waitKey(0)
            if key == ord('y') or key == ord('Y') :
                if not Backend.check_for_duplicates(good_img_file, bad_img_file) :
                    # Create and save mask from which thickness determination should take place
                    cv2.imwrite(good_img_file, (np.add((cornea[:,:,im] * 255), (ovd[:,:,im]) * 127))) 
                else :
                    print("[WARNING:] image with same number in both folders")  
                    continue
            elif key == ord('n') or key == ord('N') :
                if not Backend.check_for_duplicates(good_img_file, bad_img_file) :
                    plt.imsave(bad_img_file, scans[:,:,im], cmap='gray')
                else :
                    print("[WARNING:] image with same number in both folders")
                    continue
            else :
                print("You have pressed an invalid key... [EXITING LOOP]")
                cv2.destroyAllWindows()
                sys.exit(0)
            cv2.destroyAllWindows()
        
        print("Done displaying images!")
        return
           