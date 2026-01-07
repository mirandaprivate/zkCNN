//
// Created for MLP demo
//

#include "circuit.h"
#include "neuralNetwork.hpp"
#include "verifier.hpp"
#include "models.hpp"
#include "global_var.hpp"

// the arguments' format
#define INPUT_FILE_ID 1     // the input filename
#define CONFIG_FILE_ID 2    // the config filename
#define OUTPUT_FILE_ID 3    // the output filename
#define PIC_CNT 4           // the number of pictures paralleled
#define INPUT_SIZE_ID 5     // optional: size n for n×n fully-connected layers
#define NUM_LAYER_ID 6      // optional: number of fully-connected layers

vector<std::string> output_tb(16, "");

int main(int argc, char **argv) {
    initPairing(mcl::BLS12_381);

    char i_filename[500], c_filename[500], o_filename[500];

    strcpy(i_filename, argv[INPUT_FILE_ID]);
    strcpy(c_filename, argv[CONFIG_FILE_ID]);
    strcpy(o_filename, argv[OUTPUT_FILE_ID]);

    int pic_cnt = atoi(argv[PIC_CNT]);

    // Default values from global_var.hpp
    i64 input_output_size = FC_NETWORK_INPUT_SIZE;
    i64 num_layers = FC_NETWORK_NUM_LAYERS;

    // Override with command line arguments if provided
    if (argc > INPUT_SIZE_ID) {
        input_output_size = atoll(argv[INPUT_SIZE_ID]);
    }
    if (argc > NUM_LAYER_ID) {
        num_layers = atoll(argv[NUM_LAYER_ID]);
    }

    output_tb[MO_INFO_OUT_ID] = "mlp (relu)";
    output_tb[PCNT_OUT_ID] = std::to_string(pic_cnt);

    prover p;
    fullyConnectedNetwork nn(input_output_size, num_layers, pic_cnt, i_filename, c_filename, o_filename);
    nn.create(p, false);
    verifier v(&p, p.C);
    v.verify();

    for (auto &s: output_tb) printf("%s, ", s.c_str());
    puts("");
}