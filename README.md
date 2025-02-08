# Windows New Menu Editor

A **Python GUI tool** for managing Windows **"New"** context menu items. This application allows you to:
- **Add custom file templates** to the right-click **"New"** menu.
- **Remove selected default items** from the **"New"** menu.
- **Store templates** in `%APPDATA%/CustomNewTemplates`.
- **Open the template directory** for easy management.

---

## 📌 Features
✅ **Add custom file templates**  
✅ **Remove selected default items**  
✅ **Store templates for reuse**  
✅ **Open template directory easily**  

---

## 🛠️ Prerequisites

Before running the application, ensure you have the following installed:

- **Python 3.x**
- **PyQt5**

Install PyQt5 using the following command:

```sh
pip install PyQt5
```

---

## 🚀 How to Use

### **Option 1: Run the Python Script**
1️⃣ **Run the script:**
   ```sh
   python script.py
   ```

2️⃣ **Adding a Template:**
   - Click **"Add Template"**.
   - Select a file from your computer.
   - The file will be copied to `%APPDATA%/CustomNewTemplates` and added to the **"New"** menu.

3️⃣ **Removing a Template:**
   - Select a custom template from the list.
   - Click **"Remove Selected"**.
   - The file will be removed from the system and the **"New"** menu.

4️⃣ **Managing Default Items:**
   - Click **"Load Default Items"** to list existing **"New"** menu entries.
   - Select an item and click **"Remove Selected Default Item"** to delete it from the registry.

5️⃣ **Opening the Template Directory:**
   - Click **"Open Template Directory"** to access the stored template files.

---

### **Option 2: Download Standalone EXE**
If you don’t want to run the Python script manually, you can **download the standalone executable** from the **[Releases](https://github.com/osmanonurkoc/win_new_menu_editor/releases)** section.

📥 **Steps to use the EXE version:**
1. **Download the latest release** from **[Releases](https://github.com/osmanonurkoc/win_new_menu_editor/releases)**.
2. **Run the EXE file** (No installation required).
3. Follow the same steps as the Python version.

---

## ⚠️ Important Notes
🔹 Removing default items **only removes them from the context menu**, not from the system.  
🔹 This tool modifies the **Windows Registry**. **Run with administrative privileges** if necessary.  
🔹 Restart **Windows Explorer (`explorer.exe`)** after making changes to apply them.  

---

## 📜 License
This project is **open-source** and licensed under the **MIT License**.

---

## 👥 Contributions
💡 Feel free to submit **issues** or **pull requests** to improve this project! 🚀  

## Reddit check
username:kawai_pasha
