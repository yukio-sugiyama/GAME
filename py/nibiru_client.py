import requests
from pprint import pprint
class HTTPGetException(Exception):
    pass

class Client:

    def __init__(self) -> None:
        self.rpc_address = "http://localhost:26657"


    def _get(self, url):
        res = requests.get(url)
        return res.json()


    def error_check(self, data):
        if 'error' in data:
            raise HTTPGetException(data['error'])
        return data


    def get_status(self):
        url = "/status?"

        access_url = self.rpc_address + url
        res = self._get(access_url)
        if 'error' in res:
            raise HTTPGetException(res['error'])
        return res['result']


    def get_block(self, height=1):
        url = f"/block?height={str(height)}"

        access_url = self.rpc_address + url
        res = self._get(access_url)
        if 'error' in res:
            raise HTTPGetException(res['error'])
        return res['result']


    def get_validator(self, height=1, page=None, per_page=None):
        url = f"/validators?height={str(height)}"
        if page:
            url = url + f"&page={page}"
        if per_page:
            url = url + f"&per_page={per_page}"

        access_url = self.rpc_address + url
        res = self._get(access_url)
        if 'error' in res:
            raise HTTPGetException(res['error'])
        return res['result']


    def get_net_info(self):
        url = "/net_info?"
        access_url = self.rpc_address + url
        res = self._get(access_url)
        if 'error' in res:
            raise HTTPGetException(res['error'])
        return res['result']
