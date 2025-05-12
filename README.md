# GitecOps

**GitecOps** is a system administration toolkit designed for automating hardware configuration and deployment processes in a managed IT environment, such as a technical education center. It includes utilities for BIOS configuration, task automation, logging, and device management—primarily targeting HP systems.

## 🧩 Project Structure

```
GitecOps/
├── assets/
│   └── BiosConfig/        # HP BIOS Configuration Utilities and Documentation
│   └── BIOSSetup/         # BIOS password management tools
├── scripts/
│   ├── modules/           # PowerShell module scripts
│   ├── startup/           # Startup automation scripts
│   └── maintenance/       # Maintenance and cleanup tasks
├── Setup/                 # Initial setup scripts
├── .gitignore             # Standard Git exclusions
├── LICENSE                # Project licensing info
├── README.md              # This file
```

## ⚙️ Features

- 🧠 **Modular PowerShell Scripts** – For startup tasks, maintenance, and device configuration.
- 🔐 **HP BIOS Configuration** – Includes HP tools and documentation to support BIOS automation.
- 🛠️ **Device Management Support** – Designed to streamline large-scale deployments in classrooms or labs.
- 📝 **Logging Framework** – Extensible logging module included.

## 🚀 Getting Started

1. **Clone the Repository:**

   ```powershell
   git clone https://github.com/MrFrey75/GitecOps.git
   ```

2. **Review Modules:**

   The main scripts live in:

   ```
   C:\GitecOps\scripts\modules\
   ```

   Key modules:
   - `LoggingHelper.psm1`
   - `Utilities.psm1`
   - `RegistryHelper.psm1`
   - `DeviceHelper.psm1`

3. **Execute Setup Scripts:**

   Initial setup scripts live in the `Setup/` directory and may include installation and scheduling of tasks.

4. **Use in Scheduled Tasks or Intune:**

   These scripts can be deployed via Microsoft Intune or Windows Scheduled Tasks for automation at startup, daily, or weekly intervals.

## 🛡️ Security Considerations

- HP BIOS tools rely on password management binaries (`HpqPswd.exe`)—make sure these are used securely.
- Store sensitive passwords securely using encrypted secure strings or managed secrets systems.

## 📄 License

This project is licensed under the [MIT License](https://github.com/MrFrey75/GitecOps/blob/main/LICENSE).

## 🙋‍♂️ Maintainer

Built and maintained by [@MrFrey75](https://github.com/MrFrey75) for GITEC (Gradient Isabella Technical Education Center).
