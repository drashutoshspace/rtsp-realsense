import pyrealsense2 as rs

ctx = rs.context()
connected_devices = ctx.query_devices()

if not connected_devices:
    print("No RealSense devices found.")
else:
    for i, dev in enumerate(connected_devices):
        print(f"\nDevice {i+1}:")
        print("  Name:", dev.get_info(rs.camera_info.name))
        print("  Serial Number:", dev.get_info(rs.camera_info.serial_number))
        print("  Firmware Version:", dev.get_info(rs.camera_info.firmware_version))
        print("  USB Port:", dev.get_info(rs.camera_info.physical_port))
