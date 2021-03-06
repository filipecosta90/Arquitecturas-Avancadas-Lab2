/**************************************************************
 * 
 * --== Simple CUDA kernel ==--
 * author: ampereira
 * 
 *
 * Fill the rest of the code
 *
 * Insert the functions for time measurement in the correct 
 * sections (i.e. do not account for filling the vectors with random data)
 *
 * Before compile choose the CPU/CUDA version by running the bash command:
 *     export CUDA=yes    or    export CUDA=no
 *
 **************************************************************/
#include <stdio.h>
#include <cstdlib>
#include <iostream>
#include <sys/time.h>

#define TIME_RESOLUTION 1000000	// time measuring resolution (us)
#define NUM_BLOCKS 128
#define STRIDE_SIZE 16
#define NUM_THREADS_PER_BLOCK 256
#define SIZE NUM_BLOCKS*NUM_THREADS_PER_BLOCK
#define RADIUS 2

using namespace std;
timeval t;

long long unsigned cpu_time;
cudaEvent_t start, stop;

// These are specific to measure the execution of only the kernel execution - might be useful
void startKernelTime (void) {
  cudaEventCreate(&start);
  cudaEventCreate(&stop);

  cudaEventRecord(start);
}

void stopKernelTime (char * discription) {
  cudaEventRecord(stop);

  cudaEventSynchronize(stop);
  float milliseconds = 0;
  cudaEventElapsedTime(&milliseconds, start, stop);

  cout << milliseconds << " ms have elapsed for the kernel " << discription << " execution" << endl;
}

// Fill the input parameters and kernel qualifier
__global__ void stencilKernelStride (float *in, float *out) {

  for ( int tid = threadIdx.x + blockIdx.x * blockDim.x; tid < SIZE; tid += STRIDE_SIZE ){
    float value = 0.0f;
    for ( int pos = -RADIUS; pos <= RADIUS; pos++ ){
      value += in[tid+pos];
    }
    out[tid]=value;
  }
}

__global__ void stencilKernelSharedMemory (float *in, float *out){
  int tid = threadIdx.x + blockIdx.x * blockDim.x;
  float value = 0.0f;
  __shared__ float temp[NUM_THREADS_PER_BLOCK+2*RADIUS];
 temp[threadIdx.x + RADIUS] = in[tid];
	if(threadIdx.x < RADIUS ){
	 	//before
		if (tid - threadIdx.x >= 0){
			temp[threadIdx.x] = in[tid - threadIdx.x];
		}
	 	//after
		if ( tid + threadIdx.x < SIZE){
			temp[threadIdx.x+blockDim.x] = in[tid + threadIdx.x];
		}
	 }
  __syncthreads();

    for(int pos = 0; pos<=2*RADIUS; pos++){
    value += temp[pos];
  }

  out[tid] = value;
}

/*
// Fill the input parameters and kernel qualifier
void quicksortKernel (???) {

}
 */

// Fill with the code required for the GPU stencil (mem allocation, transfers, kernel launch....)
void stencilGPU (void) {

  int bytes = SIZE*sizeof(int);
  float vector[SIZE], output_vector[SIZE];
  float *dev_vector, *dev_output;

  // create random vector
  for (unsigned i = 0; i<SIZE; i++){
    vector[i]=(float) rand()/RAND_MAX;
  }

  // malloc memmory device
  cudaMalloc((void**)&dev_vector,bytes);
  cudaMalloc((void**)&dev_output,bytes);
  startKernelTime();
  // copy inputs to the device
  cudaMemcpy(dev_vector,&vector,bytes,cudaMemcpyHostToDevice);

  // launch the kernel
  // instead of number o blocks we now have stride size
  dim3 dimGrid(NUM_BLOCKS);
  dim3 dimBlock(NUM_THREADS_PER_BLOCK);

  stencilKernelStride<<<dimBlock,dimGrid>>>(dev_vector,dev_output);
  cudaDeviceSynchronize();
  stopKernelTime("Stride");
  // copy the output to the host
  startKernelTime();
  stencilKernelSharedMemory <<<dimBlock,dimGrid>>>(dev_vector,dev_output);
  stopKernelTime("Shared Memory");
  startKernelTime();
  cudaMemcpy(&output_vector,dev_output,bytes,cudaMemcpyDeviceToHost);
  stopKernelTime("cudaMemcpy");

  // free the device memory
  cudaFree(dev_vector);
  cudaFree(dev_output);
}
/*
// Fill with the code required for the GPU quicksort (mem allocation, transfers, kernel launch....)
void quicksortGPU (void) {

}*/

int main (int argc, char** argv){

  stencilGPU();
  return 0;
}

