#!/usr/bin/env python3
"""
Test script to verify all dependencies are installed correctly
"""

def test_imports():
    """Test if all required modules can be imported."""
    try:
        import json
        print("✓ json module available")
    except ImportError as e:
        print(f"✗ json module error: {e}")
        return False
    
    try:
        import os
        print("✓ os module available")
    except ImportError as e:
        print(f"✗ os module error: {e}")
        return False
    
    try:
        import logging
        print("✓ logging module available")
    except ImportError as e:
        print(f"✗ logging module error: {e}")
        return False
    
    try:
        import xmltodict
        print("✓ xmltodict module available")
    except ImportError as e:
        print(f"✗ xmltodict module error: {e}")
        print("  Please install with: pip install xmltodict==0.13.0")
        return False
    
    try:
        import lxml
        print("✓ lxml module available")
    except ImportError as e:
        print(f"✗ lxml module error: {e}")
        print("  Please install with: pip install lxml==4.9.3")
        return False
    
    try:
        from kafka import KafkaConsumer
        print("✓ kafka-python module available")
    except ImportError as e:
        print(f"✗ kafka-python module error: {e}")
        print("  Please install with: pip install kafka-python==2.0.2")
        return False
    
    try:
        from datetime import datetime
        print("✓ datetime module available")
    except ImportError as e:
        print(f"✗ datetime module error: {e}")
        return False
    
    try:
        import signal
        print("✓ signal module available")
    except ImportError as e:
        print(f"✗ signal module error: {e}")
        return False
    
    try:
        import sys
        print("✓ sys module available")
    except ImportError as e:
        print(f"✗ sys module error: {e}")
        return False
    
    return True

def test_consumer_import():
    """Test if the consumer module can be imported."""
    try:
        from hes_kaifa_consumer import HESKaifaConsumer
        print("✓ HESKaifaConsumer class can be imported")
        return True
    except ImportError as e:
        print(f"✗ HESKaifaConsumer import error: {e}")
        return False

def main():
    """Run all tests."""
    print("Testing HES-Kaifa Consumer Dependencies")
    print("=" * 40)
    
    # Test basic imports
    basic_imports_ok = test_imports()
    
    print("\n" + "=" * 40)
    
    # Test consumer import
    consumer_import_ok = test_consumer_import()
    
    print("\n" + "=" * 40)
    
    if basic_imports_ok and consumer_import_ok:
        print("✓ All dependencies are installed correctly!")
        print("You can now run: python run_consumer.py")
    else:
        print("✗ Some dependencies are missing.")
        print("\nTo install missing dependencies, run:")
        print("pip install xmltodict==0.13.0 lxml==4.9.3 kafka-python==2.0.2")
        print("\nOr install from requirements.txt:")
        print("pip install -r ../requirements.txt")

if __name__ == "__main__":
    main()
