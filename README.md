# Windows New Menu Editor

A Python GUI tool for managing Windows "New" context menu items. This application allows you to add custom file templates and remove existing ones, giving you full control over the right-click "New" menu in Windows Explorer.

## Features
- **Add custom file templates** to the "New" context menu.
- **Remove selected default items** from the "New" menu.
- **Store templates in** `%APPDATA%/CustomNewTemplates`.
- **Open template directory** for easy management.

## Prerequisites

Before running the application, ensure you have the following installed:
- Python 3.x
- PyQt5

To install PyQt5, run:
```
pip install PyQt5
```

## How to Use

1. **Run the script:**
   ```
   python script.py
   ```

2. **Adding a Template:**
   - Click on "Add Template".
   - Select a file from your computer.
   - The file will be copied to `%APPDATA%/CustomNewTemplates` and added to the "New" menu.

3. **Removing a Template:**
   - Select a custom template from the list.
   - Click "Remove Selected".
   - The file will be removed from the system and the "New" menu.

4. **Managing Default Items:**
   - Click "Load Default Items" to list existing "New" menu entries.
   - Select an item and click "Remove Selected Default Item" to delete it from the registry.

5. **Opening the Template Directory:**
   - Click "Open Template Directory" to access the stored template files.

## Notes
- Removing default items **only removes them from the context menu**, not from the system.
- This tool modifies the Windows registry. **Run with administrative privileges** if necessary.
- Restart Windows Explorer (`explorer.exe`) after making changes to apply them.

## License
This project is open-source and licensed under the MIT License.

## Contributions
Feel free to submit issues or pull requests to improve this project!
