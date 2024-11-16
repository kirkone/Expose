# Image Downloader Script

This script downloads images from a OneDrive share link, processes them, and organizes them into project folders by the year the photos were taken. The script is designed to work in parallel to speed up the downloading process.

## Prerequisites

The script requires the following commands to be installed on your system:
- `curl`
- `jq`
- `xargs`
- `base64`
- `tr`

You can install them using your package manager. For example, on Ubuntu:
```bash
sudo apt-get install curl jq xargs base64 coreutils
```

## Configuration File

Before running the script, create a configuration file named `config.sh` in your project folder. This file should contain any necessary configurations. For example:

```bash
# config.sh

# OneDrive share URL
SHARE_URL="https://your-onedrive-share-link"
```

## Usage

Run the script with the following options:

```bash
./script.sh -p <project> [-c <concurrency>] [-f]
```

### Options

- `-p <project>`: The name of the project folder where images will be stored.
- `-c <concurrency>` (optional): The number of concurrent downloads. Defaults to the number of CPU cores minus one.
- `-f` (optional): Force download even if the file already exists.

### Example

```bash
./script.sh -p my_project -c 4 -f
```

This command will:
1. Check for required commands.
2. Parse the command-line arguments.
3. Create the project folder if it does not exist.
4. Source the configuration file from the project folder.
5. Fetch data from OneDrive.
6. Process the JSON response and download images in parallel.

## Notes

- The script uses strict mode to enhance error handling (`set -euo pipefail`).
- Images are organized by the year they were taken.
- The `-f` option allows for forced downloading even if files already exist.
