import os
from typing import Optional, Dict, Any
from fabric import Connection

NOTIFY_ID = "arsync" 

def nvim_notify(nvim, message, level='info', title='arsync', id=NOTIFY_ID, stop_ani=False):
    if stop_ani:
        nvim.async_call(lambda: nvim.command("let g:notify_running = v:false | if exists('g:timer_id') | call timer_stop(g:timer_id) | endif"))

    # Escape single quotes and backslashes in the message to prevent Lua syntax errors
    message = message.replace("\\", "\\\\").replace("'", "\\'")
    options = f"{{title = '{title}'"
    if id is not None:
        options += f", id = '{id}'"  # Ensure id is a string
    options += "}"
    nvim.async_call(lambda: nvim.command(
        f"lua vim.notify('{message}', vim.log.levels.{level.upper()}, {options})"
    ))

class SFTPClient:
    def __init__(self, nvim):
        self.nvim = nvim
        self._connection: Optional[Connection] = None
        self._config: Dict[str, Any] = {}

    def connect(self, config: Dict[str, Any]) -> bool:
        try:
            self._config = config
            
            # 构建连接参数
            connect_params = {
                'host': config['remote_host'],
                'user': config.get('remote_user', None),
                'port': config.get('remote_port', None),
                'connect_kwargs': {
                    'key_filename': os.path.expanduser(config.get('identity_file', '~/.ssh/id_rsa'))
                }
            }
            
            # 连接到远程主机
            self._connection = Connection(**connect_params)

            nvim_notify(self.nvim, 'SFTP connection created', 'info')
            return True
        except Exception as e:
            error_message = str(e).replace("'", "\\'")
            nvim_notify(self.nvim, f'SFTP connection failed: {error_message}', 'error')
            return False

    def transfer(self, direction: str, rel_path: str) -> bool:
        if not self._connection:
            return False

        try:
            local_path = os.path.join(self._config['local_path'], rel_path)
            remote_path = os.path.join(self._config['remote_path'], rel_path)

            if direction == "up":
                self._connection.put(local_path, remote_path)
            else:
                self._connection.get(remote_path, local_path)
            
            nvim_notify(self.nvim, f'Transfer completed: {rel_path}', 'info', stop_ani=True)
            return True
        except Exception as e:
            error_message = str(e).replace("'", "\\'")
            nvim_notify(self.nvim, f'Transfer failed: {error_message}', 'error', stop_ani=True)
            return False

    def cleanup(self):
        if self._connection:
            self._connection.close()
