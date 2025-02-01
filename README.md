# arsync.nvim

`arsync.nvim` is a Neovim plugin designed to handle asynchronous file synchronization between local and remote hosts using `rsync` or `sftp`. It provides a seamless way to sync files or entire projects with remote servers, making it ideal for developers working in remote environments.

## Features

- **Asynchronous File Synchronization**: Sync files or entire projects asynchronously using `rsync` or `sftp`.
- **Customizable Configuration**: Define sync behavior using a `.arsync` configuration file.
- **Automatic Sync on Save**: Automatically sync files to the remote server on save.
- **Interactive Notifications**: Get real-time notifications with progress animations during sync operations.
- **Toggle Sync**: Easily enable or disable sync operations with a single command.
- **Multiple Backends**: Supports both `rsync` and `sftp` backends for file synchronization.

## Installation

You can install `arsync.nvim` using your favorite plugin manager. For example, with `lazy.nvim`:

```lua
return {
  "https://github.com/MayDomine/arsync.nvim.git",
  build = ":UpdateRemotePlugins",
  event = "BufWritePost",

  dependencies = {
    "folke/snacks.nvim",
  },
  config = function()
    vim.keymap.set("n", "<leader>ar", "<cmd>ARSyncProj<CR>", { desc = "ARSyncUpProj To Remote" })
    vim.keymap.set("n", "<leader>as", "<cmd>ARSyncShow<CR>", { desc = "ARSyncShow" })
    vim.keymap.set("n", "<leader>ad", "<cmd>ARSyncDownProj<CR>", { desc = "ARSyncDownProj From Remote" })
    vim.keymap.set("n", "<leader>ac", "<cmd>ARCreate<CR>", { desc = "ARSyncUp Config Create" })
    require("arsync").setup()
  end,
}

```

## Configuration

### `.arsync` Configuration File

Create a `.arsync` file in your project root to configure the sync behavior. Here's an example configuration:
You can just use `:ARCreate` to generate a `.arsync` file in your project root.
```json
auto_sync_up 0
local_options -var
local_path /Users/tachicoma/.local/share/nvim/lazy/arsync.nvim
remote_host unknown
remote_options -var
remote_or_local remote
remote_path unknown
remote_port 0
rsync_flags ["--max-size=100m"]
```

### Key Configuration Options

- **`remote_host`**: The remote host to sync with.
- **`remote_user`**: The username for the remote host.
- **`remote_port`**: The SSH port for the remote host (default: 22).
- **`remote_path`**: The path on the remote host to sync with.
- **`local_path`**: The local path to sync.
- **`backend`**: The backend to use (`rsync` or `sftp`).
- **`auto_sync_up`**: Automatically sync files to the remote server on save (1 for enabled, 0 for disabled).
- **`rsync_flags`**: Additional flags to pass to the `rsync` command.
- **`transmit_deltas`**: Whether to transmit only file deltas (default: false).

## Usage

### Commands

- **`:ARSync`**: Sync the current file to the remote server.
- **`:ARSyncProj`**: Sync the entire project to the remote server.
- **`:ARSyncDown`**: Sync the current file from the remote server.
- **`:ARSyncDownProj`**: Sync the entire project from the remote server.
- **`:ARSyncDelete`**: Sync and delete the current file on the remote server.
- **`:ARSyncShow`**: Show the current configuration.
- **`:ARSyncToggle`**: Toggle sync operations on or off.
- **`:ARSyncEnable`**: Enable sync operations.
- **`:ARSyncDisable`**: Disable sync operations.
- **`:ARCreate`**: Create a new `.arsync` configuration file in the current project.
- **`:ARClear`**: Delete the global configuration file.

### Keybindings

- **`<leader>ar`**: Sync the entire project to the remote server.
- **`<leader>as`**: Show the current configuration.
- **`<leader>ad`**: Sync the entire project from the remote server.
- **`<leader>ac`**: Create a new `.arsync` configuration file.

## Example Workflow

1. **Create a `.arsync` Configuration File**:
   - Run `:ARCreate` to generate a `.arsync` file in your project root.
   - Edit the `.arsync` file to specify your remote host, paths, and other settings.

2. **Sync Files**:
   - Use `:ARSync` to sync the current file to the remote server.
   - Use `:ARSyncProj` to sync the entire project.

3. **Sync from Remote**:
   - Use `:ARSyncDown` to sync the current file from the remote server.
   - Use `:ARSyncDownProj` to sync the entire project from the remote server.

4. **Toggle Sync**:
   - Use `:ARSyncToggle` to enable or disable sync operations.

5. **View Configuration**:
   - Use `:ARSyncShow` to view the current configuration.

## License

`arsync.nvim` is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on the [GitHub repository](https://github.com/kenhasselmann/arsync.nvim).

## Acknowledgments

- Inspired by various file synchronization tools and plugins.
- Built with the help of the Neovim community and ecosystem.

---

Enjoy seamless file synchronization with `arsync.nvim`! 🚀
