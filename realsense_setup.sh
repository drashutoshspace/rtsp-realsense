#!/bin/bash
set -e -o pipefail

sudo apt-get update && sudo apt-get upgrade
sudo apt-get install libssl-dev libusb-1.0-0-dev libudev-dev pkg-config libgtk-3-dev git wget cmake build-essential python3 python3-dev  libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev python3-pybind11 python3-venv
git clone https://github.com/IntelRealSense/librealsense.git ~/librealsense

## BUILD

cd ~/librealsense 
./scripts/setup_udev_rules.sh

mkdir ~/librealsense/build 
cd ~/librealsense/build

cmake ../ -DBUILD_PYTHON_BINDINGS:bool=true -DPYTHON_EXECUTABLE=$(which python3)

make -j$(nproc)
sudo make install

## Creating python pkg

cp ~/librealsense/build/Release/pyrealsense2.cpython-*.so ~/librealsense/wrappers/python/pyrealsense2/
cp ~/librealsense/build/Release/librealsense2.so ~/librealsense/wrappers/python/pyrealsense2/
python3 ~/librealsense/wrappers/python/find_librs_version.py ~/librealsense/ ~/librealsense/wrappers/python/pyrealsense2/

mkdir ~/librealsense/venv
python3 -m venv ~/librealsense/venv
. ~/librealsense/venv/bin/activate
cd ~/librealsense/wrappers/python/
pip install .

echo "DONE !"
python3 -c "import pyrealsense2 as rs; print(rs.pyrealsense2.__doc__)" # this should print the doc
deactivate


## DONE

echo "
Your python package is ready to be installed at: '~/librealsense/wrappers/python/' 
"

echo "Install it, possibly after activating a venv:
'''
cd ~/librealsense/wrappers/python/
pip install .
'''
"

echo "A python3 venv containing only pyrealsense2 has been created, activate it using
'''
. ~/librealsense/venv/bin/activate
'''
"
