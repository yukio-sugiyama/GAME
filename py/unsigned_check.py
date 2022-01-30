#############
# Checks if the specified address has a signature. Frequency is every 1 minute.
# 指定したアドレスが署名をしているかチェックします。頻度は1分間隔。
#############
from logging import Formatter, handlers, StreamHandler, getLogger, DEBUG, INFO, ERROR
import traceback
from pprint import pprint
import datetime
import time
import json
import requests
import os
import sys
import configparser

import nibiru_client

args = sys.argv
PRE = str(args[1])

config = configparser.ConfigParser()
config.read('nibiru.ini')

log_file = config[PRE]['log_file']
my_address = config[PRE]['my_address']
discord_url = config[PRE]['discord_url']
file_name = config[PRE]['file_name']

rpc = nibiru_client.RPCClient()

if os.path.exists(file_name):
    with open(file_name) as f:
        st_height = int(f.read())
else:
    st_height = 1


def log_set(name=__name__, level=INFO, file=__name__ + '.log'):
    try:
        logger = getLogger(name)
        logger.setLevel(level)

        formatter = Formatter('[%(asctime)s] [%(process)d] [%(name)s] [%(levelname)s] %(message)s')

        handler = StreamHandler()
        handler.setLevel(level)
        handler.setFormatter(formatter)
        logger.addHandler(handler)

        handler = handlers.RotatingFileHandler(filename = file, maxBytes = 1048576, backupCount = 3)

        handler.setLevel(level)
        handler.setFormatter(formatter)
        logger.addHandler(handler)

        return logger

    except Exception as e:
        log.info(e)
        log.info(traceback.format_exc())

def discord_Notify(url, message, fileName=None):
    try:
        payload = {"content": " " + message + " "}
        if fileName == None:
            try:
                requests.post(url, data=payload)
            except:
                pass
        else:
            try:
                files = {"imageFile": open(fileName, "rb")}
                requests.post(url, data=payload, files=files)
            except:
                pass

    except Exception as e:
        log.info(e)
        log.info(traceback.format_exc())

def date_to_jstdt(date):
    date_len = len(date)

    if date_len > 20:
        utc_split = datetime.datetime(
            int(date[0:4]),int(date[5:7]),int(date[8:10]),
            int(date[11:13]),int(date[14:16]),int(date[17:19]),int(date[20:min(26, date_len-1)])
        )
    else:
        utc_split = datetime.datetime(
            int(date[0:4]),int(date[5:7]),int(date[8:10]),
            int(date[11:13]),int(date[14:16]),int(date[17:19])
        )

    exec_date = utc_split + datetime.timedelta(hours=+9)
    return datetime.datetime.timestamp(exec_date)

# Start processing
try:
    log = log_set('nibiru', INFO, log_file)
    log.info(f"-- Start processing --")

    while True:
        time.sleep(60)
        log.info(f"-- Start loop --")
        log.info(f"check start height:{st_height}")

        is_error = False

        try:
            res = rpc.get_status()
        except Exception as e:
            log.error(f"Error:get status\n{e}")
            is_error = True

        if is_error:
            continue

        now_height = int(res['sync_info']['latest_block_height'])

        log.info(f"check end   height:{now_height}")

        chk_height = st_height
        for i in range(now_height - st_height + 1):
            chk_height = st_height + i

            try:
                res = rpc.get_block(chk_height)
            except Exception as e:
                log.error(f"Error:get block\n{e}")
                is_error = True
                break

            sign_chk = False
            t = date_to_jstdt(res['block']['header']['time'])
            for x in res['block']['last_commit']['signatures']:
                if my_address == x['validator_address']:
                    sign_chk = True

            log.info(f"check height:{chk_height} {'Signed' if sign_chk else 'Unsigned'}")
            if not sign_chk:
                discord_Notify(discord_url, f"`Unsigned height:{chk_height} date:{datetime.datetime.fromtimestamp(t).strftime('%Y/%m/%d %H:%M:%S')}`")
                log.info(f"Unsigned height:{chk_height} date:{datetime.datetime.fromtimestamp(t).strftime('%Y/%m/%d %H:%M:%S')}")

            time.sleep(0.2)

        if is_error:
            continue

        if chk_height > st_height:
            st_height = chk_height + 1
            with open(file_name, mode='w') as f:
                f.write(str(st_height))

except Exception as e:
    log.error(e)
    log.error(traceback.format_exc())
    discord_Notify(discord_url, f"Error:Unexpected error [{args}]")
