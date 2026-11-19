# System Settings > Dock (DECISIONS.md D27). Built in the "native" stage of
# image/Containerfile against the base image's own KDE libraries.
cmake_minimum_required(VERSION 3.20)
project(kestrel-dock-settings LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
# Install plugins where Qt looks for them (/usr/lib64/qt6/plugins), as Fedora's KDE packages do.
set(QT_MAJOR_VERSION 6)
set(KDE_INSTALL_USE_QT_SYS_PATHS ON CACHE BOOL "")
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml Quick)
find_package(KF6 REQUIRED COMPONENTS KCMUtils CoreAddons)

kcmutils_add_qml_kcm(kcm_kestreldock SOURCES kcm.cpp)
target_link_libraries(kcm_kestreldock PRIVATE Qt6::DBus Qt6::Qml KF6::KCMUtilsQuick KF6::CoreAddons)
