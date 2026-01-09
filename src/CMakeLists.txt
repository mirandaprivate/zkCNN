add_library(cnn_lib STATIC
    circuit.cpp
    models.cpp
    neuralNetwork.cpp
    polynomial.cpp
    prover.cpp
    utils.cpp
    verifier.cpp
)
if(OpenMP_CXX_FOUND)
    target_link_libraries(cnn_lib PUBLIC OpenMP::OpenMP_CXX)
    target_compile_options(cnn_lib PUBLIC ${OpenMP_CXX_FLAGS})
endif()

# 确保目标按正确顺序链接
add_executable(demo_vgg_run main_demo_vgg.cpp)
target_link_libraries(demo_vgg_run cnn_lib hyrax_lib mcl mclbn384_256)

add_executable(demo_lenet_run main_demo_lenet.cpp)
target_link_libraries(demo_lenet_run cnn_lib hyrax_lib mcl mclbn384_256)

add_executable(demo_mlp_run main_demo_mlp.cpp)
target_link_libraries(demo_mlp_run cnn_lib hyrax_lib mcl mclbn384_256)
add_dependencies(demo_mlp_run cnn_lib hyrax_lib)