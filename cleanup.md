# Cleanup Script

This bash script is designed to clean up specific directories in your project folder. It takes a project name as a parameter and deletes the following directories if they exist:
- `.cache/<projectname>`
- `output/<projectname>`

## Usage

### Making the Script Executable

Save the script to a file, for example `cleanup.sh`, and make it executable with the following command:

```bash
chmod +x cleanup.sh
```

### Running the Script

Run the script with the `-p` parameter to specify the project name:

```bash
./cleanup.sh -p myproject
```

This will delete the `.cache/myproject` and `output/myproject` directories if they exist.

## Example

To clean up directories for a project named `example.site`, use the following command:

```bash
./cleanup.sh -p example.site
```

This will delete the `.cache/example.site` and `output/example.site` directories if they exist.

## Notes

- Ensure you have the necessary permissions to delete the directories.
- The script will display a message if the directories do not exist.
