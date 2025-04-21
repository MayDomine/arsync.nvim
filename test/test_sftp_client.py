import sys
import paramiko
paramiko.util.log_to_file('./paramiko.log')

sys.path.append("../rplugin/python3/")
from arsync import SFTPClient


config = {
    "remote_port": "0",
    "remote_host": "172.20.14.32.km",
    "remote_path": "/home/sunao/mega-lm",
    "local_path": "/Users/tachicoma/projects/modelbest/mega-lm",
}
client = SFTPClient(None)
client.connect(config)
client.transfer("up", "a.txt")
