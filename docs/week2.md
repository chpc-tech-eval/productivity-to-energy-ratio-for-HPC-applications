# Power Management and Monitoring

## Using ```cpupower``` to Set CPU Frequency Governors
The `cpupower` utility allows you to manage CPU frequency scaling and set different governors to optimize performance or energy efficiency. Here’s how to use it:
1. **Install cpupower** (if not already installed):
   ```bash
   sudo apt-get install linux-tools-common linux-tools-$(uname -r)
   ```
2. **Check Current Governor**:
   ```bash
   cpupower frequency-info
   ```
3. **Set Governor**:
   To set the CPU governor to "performance":
   ```bash
   sudo cpupower frequency-set -g performance
   ```
   To set it to "powersave":
   ```bash
   sudo cpupower frequency-set -g powersave
   ```
4. **Verify the Change**:
   ```bash
   cpupower frequency-info
   ```   
5. **Set cpu frequency manually**:
   You can also set a specific frequency range:
   ```bash
   sudo cpupower frequency-set --max 5.3GHz --min 2.0GHz
   ``` 