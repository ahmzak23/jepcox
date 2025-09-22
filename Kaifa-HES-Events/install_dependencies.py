#!/usr/bin/env python3
"""
Installation script for HES-Kaifa Consumer dependencies
"""

import subprocess
import sys
import os

def run_command(command):
    """Run a command and return the result."""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def install_package(package):
    """Install a Python package."""
    print(f"Installing {package}...")
    success, stdout, stderr = run_command(f"pip install {package}")
    
    if success:
        print(f"✓ {package} installed successfully")
        return True
    else:
        print(f"✗ Failed to install {package}")
        print(f"Error: {stderr}")
        return False

def main():
    """Install all required dependencies."""
    print("HES-Kaifa Consumer - Dependency Installation")
    print("=" * 50)
    
    # Required packages
    packages = [
        "xmltodict==0.13.0",
        "lxml==4.9.3",
        "kafka-python==2.0.2",
        "python-dateutil==2.8.2"
    ]
    
    print("Installing required packages...")
    print()
    
    success_count = 0
    for package in packages:
        if install_package(package):
            success_count += 1
        print()
    
    print("=" * 50)
    print(f"Installation Summary: {success_count}/{len(packages)} packages installed successfully")
    
    if success_count == len(packages):
        print("✓ All dependencies installed successfully!")
        print("You can now run: python run_consumer.py")
    else:
        print("✗ Some packages failed to install.")
        print("Please check the error messages above and try installing manually:")
        print("pip install xmltodict==0.13.0 lxml==4.9.3 kafka-python==2.0.2 python-dateutil==2.8.2")
    
    print("\nTo test the installation, run:")
    print("python test_installation.py")

if __name__ == "__main__":
    main()
