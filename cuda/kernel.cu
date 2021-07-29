//TODO: give a thread multiple points
//TODO: let the thread calculate a color

extern "C"
{
#include <stdio.h>
#include <cuda.h>
#include <stdio.h>
#include "kernel.cuh"
#include "common.cuh"
    __global__ void test()
    {
        printf("Hello from cuda Core !\n");
    }

    __global__ void calculate_iterations(int *res, int len, double xDelta, double yDelta, double xStart, double yStart, int iterations)
    {
        int row = blockIdx.y * blockDim.y + threadIdx.y;
        int col = blockIdx.x * blockDim.x + threadIdx.x;

        double x_c = col * xDelta + xStart;
        double y_c = row * yDelta + yStart;
        double x = 0;
        double y = 0;
        double x_old = 0;
        double y_old = 0;
        //iterate this point, check if it's in the set or not; write a result in res
        for(int i=0; i<iterations; i++){
            x = x_old * x_old - y_old * y_old + x_c;
            y = 2 * x_old * y_old + y_c;
            double d_sq = x * x + y * y;

            if(d_sq >= 9){
                res[col + gridDim.x * blockDim.x * row] = i+1;
                return;
            }
            x_old = x;
            y_old = y;
        }
        res[col + gridDim.x * blockDim.x * row] = -1;
    }

    __global__ void generate_texture(int *iterations, uint8_t *tex_buff){

        int row = blockIdx.y * blockDim.y + threadIdx.y;
        int col = blockIdx.x * blockDim.x + threadIdx.x;
        int it_index = col + gridDim.x * blockDim.x * row;
        
        uint8_t s = (1 + (iterations[it_index] >= 0) - (iterations[it_index] < 0)) / 2; // it = -1 --> s = 0, it >= 0 --> s = 1
        
        int tex_index = gridDim.x * blockDim.x * row * 3 + col * 3;
        tex_buff[tex_index] = s * (iterations[it_index] * 4); //red
        tex_buff[tex_index+1] = s * (30 + iterations[it_index] * 3); //green
        tex_buff[tex_index+2] = s * (100 + iterations[it_index] * 4); //blue
    }

    void launch_test()
    {

        // Call the kernel:
        test<<<1, 1>>>();
        cudaDeviceSynchronize();
    }

    void launch_mandelbrot(Config con, char *out)
    {

        //buffer containing iterations
        int *iterations;
        int it_len = con.xDim * con.yDim;
        CHECK(cudaMalloc((int **)&iterations, it_len * sizeof(int)));
        cudaMemset(iterations, 0, it_len);

        //buffer containing texture data
        uint8_t *tex_buff;
        int tex_len = con.xDim * con.yDim * 3;
        CHECK(cudaMalloc((uint8_t **)&tex_buff, tex_len * sizeof(uint8_t)));
        cudaMemset(tex_buff, 0, tex_len);

        //buffer containing resulting image data
        uint8_t *img_buff;
        int img_len = con.xResolution * con.yResolution * 3;
        CHECK(cudaMalloc((uint8_t **)&img_buff, img_len * sizeof(uint8_t)));
        cudaMemset(img_buff, 0, img_len);

        printf("here\n");
        //build cluster
        dim3 block(BLOCK_SIZE, BLOCK_SIZE);
        dim3 grid(ceilf((float) con.xDim / (float) BLOCK_SIZE), ceilf((float) con.yDim / (float) BLOCK_SIZE));

        CHECK(cudaDeviceSynchronize());

        calculate_iterations<<<grid, block>>>(iterations, it_len, con.xDelta, con.yDelta, con.xStart, con.yStart, con.iterations);

        CHECK(cudaDeviceSynchronize());

        generate_texture<<<grid, block>>>(iterations, tex_buff);

        CHECK(cudaDeviceSynchronize());

        CHECK(cudaGetLastError());
        // CHECK(cudaMemcpy(out, iterations, len * sizeof(int), cudaMemcpyDeviceToHost));
        CHECK(cudaMemcpy(out, tex_buff, tex_len * sizeof(uint8_t), cudaMemcpyDeviceToHost));
        

        printf("here\n");
        CHECK(cudaFree(iterations));
        CHECK(cudaFree(tex_buff));
        CHECK(cudaFree(img_buff));
    }

    void print_config(Config c)
    {
    }
}
