//Sabraaj Bajwa 1724962

#include <stdio.h>
#include <stdlib.h>
#include "lodepng.h" 

// rgbt - each pixel contains 4 values, to blur, all surrounding pixels need to be considered 
// don't edit t on output because that will impact transparency - hiran kept it the same for neg filter

__global__ void boxBlurFilter(unsigned char * inputImage, unsigned char * outputImage){

    int tIdy = threadIdx.y; // otherwise referred to as the threadindex within a block associated with threads - declaration of variable
    int tIdx = threadIdx.x;  // otherwise referred to as the threadindex within a block associated with threads - declaration of variable   
    
    int r;
    int g;
    int b;
    int t;
    
    int threadIndex = (threadIdx.y * blockDim.x + threadIdx.x); 
    int pixel = threadIndex * 4;  // multiply the above variable by 4 for use within inputImage and outputImage

    r = inputImage[pixel]; // obtains rgb offset value
    g = inputImage[pixel+1]; // obtains rgb offset value
    b = inputImage[pixel+2]; // obtains rgb offset value
    t = inputImage[pixel+3]; // obtains rgb offset value
    
    outputImage[pixel] = 0; // declares the value as 0 prepared for the adjusted value later on in the function after running through the for loop 
    outputImage[pixel+1] = 0; // declares the value as 0 prepared for the adjusted value later on in the function after running through the for loop 
    outputImage[pixel+2] = 0; // declares the value as 0 prepared for the adjusted value later on in the function after running through the for loop 
    outputImage[pixel+3] = t; // obtains rgb offset but we do not affect the transparency as much as instructed in the lecture 

    int count = 0; // sets variable count to 0
    int sumofr = 0; // sets variable count to 0
    int sumofg = 0; // sets variable count to 0
    int sumofb =0; // sets variable count to 0

    for(int i = -1; i <=1; ++i) {
        for(int j = -1; j <= 1; ++j) { 
            int k = tIdy + i; // adds the value of i in the for statement to threadIdx.y
            int l = tIdx + j; // adds the value of j in the for statement to threadIdx.x

            if(k < 0) continue; // if the threadIdx.y is less than 0, then continue with the for loop 
            if(k >= blockDim.y) continue; // if the threadIdx.y is greater than the size of each block, continue the loop 
            if(l < 0) continue; // if the threadIdx.x is less than 0, then continue with the for loop 
            if(l >= blockDim.x) continue; // if the threadIdx.x is greater or equal to the size of each block (x), continue

            ++count; // count will increase by 1 whilst executing line as opposed to count++ which is after the statement is executed

            int threadIndexNew = (k * blockDim.x + l); // Produces a new threadIndex using the variables above which change throughout the loop 
            int pixelNew = 4 * threadIndexNew;  // multiplies the above by 4 

            r = inputImage[pixelNew]; // assigns new value to r using newly calculated threadIndexNew / pixelNew value 
            g = inputImage[pixelNew+1]; // assigns new value to r using newly calculated threadIndexNew / pixelNew value
            b = inputImage[pixelNew+2]; // assigns new value to r using newly calculated threadIndexNew / pixelNew value

            sumofr += r; // This adds r to sumofr then assigns the overall value to sumofr
            sumofg += g; // This adds g to sumofg then assigns the overall value to sumofg
            sumofb += b; // This adds b to sumofb then assigns the overall value to sumofb

        }
    }

    outputImage[pixel] += sumofr / count; // we divide by count to obtain the average, and then assign that value to output image[pixel] plus the original value of outputimage[pixel]
    outputImage[pixel+1] += sumofg / count; // we divide by count to obtain the average, and then assign that value to output image[pixel+1] plus the original value of outputimage[pixel+1]
    outputImage[pixel+2] += sumofb / count; // we divide by count to obtain the average, and then assign that value to output image[pixel+2] plus the original value of outputimage[pixel+2]
   
}
    
    int main(int argc, char ** argv){
    
      unsigned int errorDecode; //variable will hold whether there was an issue with loading in the png file
      unsigned char* cpuImage; //this variable will hold all of our image data
      unsigned int width, height; //holds the width and height of image
      
      char * filename = argv[1]; // works as pointers for the first command line argument, so when running the program, it requires the file name and the new file name, this line is for the file name only
      char * newFilename = argv[2]; // works as pointers for the second command line argument, so when running the program, it requires the file name and the new file name, this line is for the new file name only so e.g. test.png
    
      errorDecode = lodepng_decode32_file(&cpuImage, &width, &height, filename); // (where to store the image data, width, height, which file?)
      
      if(errorDecode){
        printf("error %u: %s\n", errorDecode, lodepng_error_text(errorDecode));  // if error is found when decoding image, print error message 
      }
      
      printf("width of image is %d\nheight of image is %d\n", width, height); // States the height and width of the image, which for test purposes was the 4x4.png file so 4 by 4

      int arraySize = width*height*4; // 
      int memorySize = arraySize * sizeof(unsigned char); //sizeof(unsigned char) is multiplied by array size to produce a value stored in arraysize
      
      unsigned char cpuOutImage[arraySize];
      
      unsigned char* gpuInput; // used as a means to store character values which stores values from 0-255 since it is unsigned
      unsigned char* gpuOutput; // used as a means to store character values which stores values from 0-255 since it is unsigned
      
      cudaMalloc( (void**) &gpuInput, memorySize); // cuda malloc device array, since it returns a pointer it requires a double pointer with **void
      cudaMalloc( (void**) &gpuOutput, memorySize); // cuda malloc device array, since it returns a pointer it requires a double pointer with **void
      
      cudaMemcpy(gpuInput, cpuImage, memorySize, cudaMemcpyHostToDevice); // synchronises the kernal call with the transfer of memory 
      
      dim3 grid(1,1); // a variable of type integer vector which is used to specify dimensions, in this case 1,1 which works by the kernel executing as a grid of blocks, since the image is 4x4 it uses 4 blocks
      dim3 block(width, height); // This is a group of threads, which takes in the width and height of the image, in this case 4x4 so links with the grid function to complete boxBlurFilter below 
      boxBlurFilter<<< grid, block >>>(gpuInput, gpuOutput); // Call boxBlurFilter using the above functions with dim3, grid and block   
      cudaDeviceSynchronize(); // cudaThreadSynchronize was initially used but it is since deprecated, so for program longevity device was used instead

      cudaMemcpy(cpuOutImage, gpuOutput, memorySize, cudaMemcpyDeviceToHost); // synchronises the kernal call with the transfer of memory 
      
      unsigned int errorEncode = lodepng_encode32_file(newFilename, cpuOutImage, width, height); // encodes the file and pushes it out with the new filename specified in the command line 
      
      if(errorEncode) {
        printf("error %u: %s\n", errorEncode, lodepng_error_text(errorEncode)); // if there is an error with encoding the file and pushing it out as a new file, it will display an error message 
      }

      cudaFree(gpuInput); // returns memory for reallocation for gpuInput
      cudaFree(gpuOutput); // returns memory for reallocation for gpuOutput 
    
      free(cpuImage); // deallocates memory
    
    }
    