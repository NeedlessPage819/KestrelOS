# Kestrel OS window decoration (DECISIONS.md D26). Built in its own stage of
# image/Containerfile against the exact KDecoration/KWin version of the image.
cmake_minimum_required(VERSION 3.20)
project(kestrel-decoration LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui)
find_package(KDecoration3 REQUIRED)
find_package(KF6CoreAddons REQUIRED)

add_library(kestreldecoration MODULE kestreldecoration.cpp kestreldecoration.h)
set_target_properties(kestreldecoration PROPERTIES OUTPUT_NAME org.kestrel.decoration PREFIX "")
target_compile_options(kestreldecoration PRIVATE -Wall -Wextra -Werror=return-type)
target_link_libraries(kestreldecoration PRIVATE Qt6::Core Qt6::Gui KDecoration3::KDecoration KF6::CoreAddons)

install(TARGETS kestreldecoration DESTINATION ${CMAKE_INSTALL_PREFIX}/lib64/qt6/plugins/org.kde.kdecoration3)
