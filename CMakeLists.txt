cmake_minimum_required(VERSION 3.16)
project(VirOS-Tools)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O2 -static")

add_executable(cursed-cat src/cursed-cat/main.cpp)
add_executable(cursed-ls src/cursed-ls/main.cpp)
add_executable(cursed-vim src/cursed-vim/main.cpp)
add_executable(cursed-help src/cursed-help/main.cpp)
add_executable(cursed-mkdir src/cursed-mkdir/main.cpp)


install(TARGETS cursed-cat cursed-ls cursed-vim cursed-help cursed-mkdir DESTINATION bin)
