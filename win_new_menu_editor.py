import os
import shutil
import winreg
import sys
import subprocess
from PyQt5.QtWidgets import QApplication, QWidget, QVBoxLayout, QPushButton, QListWidget, QFileDialog, QMessageBox, QLabel

# Define the directory where custom templates are stored
TEMPLATES_DIR = os.path.join(os.getenv('APPDATA'), 'CustomNewTemplates')

class ContextMenuEditor(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Windows New Menu Editor @osmanonurkoc")
        self.setGeometry(100, 100, 450, 500)

        layout = QVBoxLayout()

        # Section for Custom Templates
        layout.addWidget(QLabel("Custom Templates"))
        self.listWidget = QListWidget()
        layout.addWidget(self.listWidget)

        self.addButton = QPushButton("Add Template")
        self.addButton.clicked.connect(self.add_template)
        layout.addWidget(self.addButton)

        self.removeButton = QPushButton("Remove Selected")
        self.removeButton.clicked.connect(self.remove_template)
        layout.addWidget(self.removeButton)

        self.openTemplateDirButton = QPushButton("Open Template Directory")
        self.openTemplateDirButton.clicked.connect(self.open_template_directory)
        layout.addWidget(self.openTemplateDirButton)

        # Section for Default Items
        layout.addWidget(QLabel("Default Items"))
        self.defaultListWidget = QListWidget()
        layout.addWidget(self.defaultListWidget)

        self.loadDefaultsButton = QPushButton("Load Default Items")
        self.loadDefaultsButton.clicked.connect(self.load_default_items)
        layout.addWidget(self.loadDefaultsButton)

        self.removeSelectedDefaultButton = QPushButton("Remove Selected Default Item")
        self.removeSelectedDefaultButton.clicked.connect(self.remove_selected_default_item)
        layout.addWidget(self.removeSelectedDefaultButton)

        self.setLayout(layout)

        # Ensure the templates directory exists
        if not os.path.exists(TEMPLATES_DIR):
            os.makedirs(TEMPLATES_DIR)

        # Load existing custom templates
        self.load_templates()

    def load_templates(self):
        """Load the list of available custom templates."""
        self.listWidget.clear()
        for file in os.listdir(TEMPLATES_DIR):
            self.listWidget.addItem(file)

    def add_template(self):
        """Add a new template to the custom templates directory."""
        file_path, _ = QFileDialog.getOpenFileName(self, "Select Template File")
        if file_path:
            file_name = os.path.basename(file_path)
            destination = os.path.join(TEMPLATES_DIR, file_name)
            shutil.copy(file_path, destination)
            self.add_registry_entry(file_name)
            self.load_templates()
            QMessageBox.information(self, "Success", f"Added '{file_name}' to New menu.")

    def remove_template(self):
        """Remove a selected template from the custom templates directory."""
        selected_item = self.listWidget.currentItem()
        if selected_item:
            file_name = selected_item.text()
            os.remove(os.path.join(TEMPLATES_DIR, file_name))
            self.remove_registry_entry(file_name)
            self.load_templates()
            QMessageBox.information(self, "Removed", f"'{file_name}' removed from New menu.")

    def add_registry_entry(self, file_name):
        """Add the template to the Windows registry for the 'New' context menu."""
        extension = os.path.splitext(file_name)[1]
        reg_path = f"{extension}\\ShellNew"
        template_path = os.path.join(TEMPLATES_DIR, file_name)

        try:
            with winreg.CreateKey(winreg.HKEY_CLASSES_ROOT, reg_path) as key:
                winreg.SetValueEx(key, "FileName", 0, winreg.REG_SZ, template_path)
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to add registry entry: {str(e)}")

    def remove_registry_entry(self, file_name):
        """Remove the template from the Windows registry."""
        extension = os.path.splitext(file_name)[1]
        reg_path = f"{extension}\\ShellNew"

        try:
            winreg.DeleteKey(winreg.HKEY_CLASSES_ROOT, reg_path)
        except FileNotFoundError:
            pass
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to remove registry entry: {str(e)}")

    def load_default_items(self):
        """Load the list of default 'New' menu items from the Windows registry."""
        self.defaultListWidget.clear()
        try:
            with winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, "") as root_key:
                index = 0
                while True:
                    try:
                        ext = winreg.EnumKey(root_key, index)
                        index += 1
                        reg_path = f"{ext}\\ShellNew"
                        try:
                            with winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, reg_path):
                                self.defaultListWidget.addItem(ext)
                        except FileNotFoundError:
                            pass
                    except OSError:
                        break
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load default items: {str(e)}")

    def remove_selected_default_item(self):
        """Remove the selected default item from the 'New' menu."""
        selected_item = self.defaultListWidget.currentItem()
        if selected_item:
            ext = selected_item.text()
            reg_path = f"{ext}\\ShellNew"
            try:
                winreg.DeleteKey(winreg.HKEY_CLASSES_ROOT, reg_path)
                self.defaultListWidget.takeItem(self.defaultListWidget.row(selected_item))
                QMessageBox.information(self, "Success", f"Removed '{ext}' from New menu.")
            except Exception as e:
                QMessageBox.warning(self, "Error", f"Failed to remove selected default item: {str(e)}")

    def open_template_directory(self):
        """Open the directory where custom templates are stored."""
        subprocess.Popen(f'explorer "{TEMPLATES_DIR}"')

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = ContextMenuEditor()
    window.show()
    sys.exit(app.exec_())
