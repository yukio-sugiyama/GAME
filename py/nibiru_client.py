import requests
from pprint import pprint
import hmac
import json
import time
import urllib.parse
from requests import Session

class HTTPGetException(Exception):
    pass

class RPCClient:

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

# 作成中
# https://v1.cosmos.network/rpc/v0.41.4
class APIClient:

    def __del__(self):
        if self.session:
            self.session.close()

    def __init__(self):
        self.api_base = "http://localhost:1317"
        self.session = Session()

    def _get(self, endpoint, payload=None, is_private=False):
        payload = dict() if payload is None else payload
        url = f'{self.api_base}{endpoint}'
        p_str = urllib.parse.urlencode(sorted(payload.items()))
        headers = {
            'accept': 'application/json',
        }
        url = f'{url}?{p_str}' if p_str else url
        self.session.cookies.clear()
        res = self.session.request('GET', url, headers=headers, timeout=5)
        return self.response_check(res)

    def _post(self, endpoint, payload):
        url = f'{self.api_base}{endpoint}'
        data = json.dumps(payload)
        ts = int(time.time() * 1000)
        headers = {
            'accept': 'application/json',
            'Content-Type': 'application/json',
        }
        self.session.cookies.clear()
        print(f"url:{url}")
        print(f"data:{data}")
        print(f"headers:{headers}")

        res = self.session.request('POST', url, data=data, headers=headers, timeout=5)
        return self.response_check(res)

    def response_check(self, data):
        try:
            res = data.json()
        except Exception as e:
            raise HTTPGetException(data)

        if data.status_code != 200:
            raise HTTPGetException(res)
        return res

    # GET API sample
    def get_bank_balance(self, address):
        url = f"/bank/balances/{address}"
        return self._get(url)

    # POST API sample -- NG --
    def post_bank_balance(self, tx_bytes='string', mode='BROADCAST_MODE_UNSPECIFIED'):
        url = f"/cosmos/tx/v1beta1/txs"
        payload = {
            'tx_bytes': tx_bytes,
            'mode': mode,
        }
        payload = {k: v for k, v in payload.items() if v is not None}
        return self._post(url, payload)
