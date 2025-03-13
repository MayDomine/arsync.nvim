import pynvim
from arsync.sftp import SFTPClient


@pynvim.plugin
class Arsync:
    def __init__(self, nvim):
        self.nvim = nvim
        self.sftp_client = None

    @pynvim.function("ArsyncSFTPTransfer")
    def sftp_transfer(self, args):
        direction, config, rel_path = args

        # 创建或获取 SFTP 客户端
        if not self.sftp_client:
            self.sftp_client = SFTPClient(self.nvim)
            if not self.sftp_client.connect(config):
                return False

        # 执行传输
        return self.sftp_client.transfer(direction, rel_path)

    @pynvim.function("ArsyncSFTPCleanup")
    def sftp_cleanup(self, args):
        if self.sftp_client:
            self.sftp_client.cleanup()
            self.sftp_client = None
