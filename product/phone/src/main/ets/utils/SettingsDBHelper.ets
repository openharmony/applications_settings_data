/**
 * @file Describe the file
 * Copyright (c) 2021 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import data_storage from '@ohos.data.storage';
import fileio from '@ohos.fileio';
import ohosDataRdb from '@ohos.data.rdb';
import SettingsDataConfig from '../utils/SettingsDataConfig';
import deviceinfo from '@ohos.deviceinfo';

let DDL_TABLE_CREATE = `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.TABLE_NAME} (`
+ `${SettingsDataConfig.FIELD_ID} INTEGER PRIMARY KEY AUTOINCREMENT, `
+ `KEYWORD TEXT, `
+ `VALUE TEXT CHECK (LENGTH(VALUE)<=1000))`;

const FILE_URI = "/data/accounts/account_0/applications/com.ohos.settingsdata"
+ "/com.ohos.settingsdata/assets/phone/resources/rawfile";

const STORAGE_URI = "/data/accounts/account_0/appdata/com.ohos.settingsdata/sharedPreference/";

let DEFAULT_JSON_FILE_PATH = FILE_URI + "/default_settings.json";
let SETTINGSDATA_PREFERENCE = STORAGE_URI + "/SettingsDataPreference";

let DefaultKey = SettingsDataConfig.DefaultKey;
let SettingsKey = SettingsDataConfig.SettingsKey;

const DefalutKVGlobal = {
  "settings.screen.brightness.default": "50",
  "settings.time.format.default": "24",
  "settings.audio.ringtone.default": "5",
  "settings.audio.media.default": "5",
  "settings.audio.voicecall.default": "5",
  "settings.display.navigationbar_status.default": "1",
};

let TAG = "SettingsDBHelper ";

class SettingsDBHelper {
  private startup_flag: boolean;
  private rdbStore_;
  private static instance_: SettingsDBHelper;

  private constructor() {
    this.startup_flag = false;
    this.rdbStore_ = undefined;
    console.log(TAG + 'call construstor');
  }

  private startupConfig() {
    console.log(TAG + "startupConfig start");
    let storage = data_storage.getStorageSync(SETTINGSDATA_PREFERENCE);
    console.log(TAG + "startupConfig getStorageSync = " + storage);
    let isExist = storage.hasSync('startup')
    console.log(TAG + "startupConfig hasSync = " + isExist);
    if (!isExist) {
      console.info(TAG + "The key of startup is not contained.")
      console.log(TAG + "startupConfig putSync start");
      storage.putSync('startup', 'auto');
      console.log(TAG + "startupConfig flushSync start");
      storage.flushSync();
      console.log(TAG + "startupConfig flushSync end");
      this.startup_flag = true;
    } else {
      let startup = storage.getSync('startup', 'null');
      console.log(TAG + "startupConfig getSync startup = " + startup);
    }
    console.log(TAG + "startupConfig end");
    return;
  }

  public async initRdbStore() {
    console.log(TAG + 'call initRdbStore start');
    this.rdbStore_ = await ohosDataRdb.getRdbStore({ name: SettingsDataConfig.DB_NAME }, 1);
    console.log(TAG + 'call initRdbStore, rdbStore_ = ' + this.rdbStore_);

    console.log(TAG + "initRdbStore executeSql");
    await this.rdbStore_.executeSql(DDL_TABLE_CREATE, []);

    console.log(TAG + 'getRdbStore startupConfig');
    this.startupConfig();

    console.log(TAG + 'initRdbStore getDefaultSettingsKV');
    let defaultKV = this.getDefaultSettingsKV();

    if (this.startup_flag) {
      console.log(TAG + 'initRdbStore loadDefaultSettings');
      await this.loadDefaultSettings(defaultKV);
    } else {
      console.log(TAG + 'initRdbStore not need loadDefaultSettings');
    }
    console.log(TAG + 'call initRdbStore end');
    return this.rdbStore_;
  }

  public static getInstance() {
    if (!SettingsDBHelper.instance_) {
      console.log(TAG + 'call getInstance start');
      SettingsDBHelper.instance_ = new SettingsDBHelper();
      console.log(TAG + 'call getInstance end');
    }
    return SettingsDBHelper.instance_;
  }

  public async getRdbStore() {
    console.log(TAG + 'call getRdbStore start');
    return await SettingsDBHelper.instance_.initRdbStore();
  }

  private async loadSettings(rdbStore_, key, value): Promise<void> {
    console.log(TAG + "key=" + key + " value " + value);
    await this.rdbStore_.insert(
      SettingsDataConfig.TABLE_NAME,
      { "KEYWORD": key, "VALUE": value },
      (err, ret) => {
        if (err) {
          console.log(TAG + "loadSettings insert error:" + JSON.stringify(err));
        }
        console.log(TAG + "loadSettings insert ret = " + ret);
      });
  }

  private async loadDefaultSettings(defaultKV) {
    console.log(TAG + "loadDefaultSettings start");

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_SCREEN_BRIGHTNESS, defaultKV[DefaultKey.SETTINGS_SCREEN_BRIGHTNESS_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_TIME_FORMAT, defaultKV[DefaultKey.SETTINGS_TIME_FORMAT_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_AUDIO_RINGTONE, defaultKV[DefaultKey.SETTINGS_AUDIO_RINGTONE_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_AUDIO_MEDIA, defaultKV[DefaultKey.SETTINGS_AUDIO_MEDIA_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_AUDIO_VOICE_CALL, defaultKV[DefaultKey.SETTINGS_AUDIO_VOICE_CALL_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_GENERAL_DEVICE_NAME, defaultKV[DefaultKey.SETTINGS_GENERAL_DEVICE_NAME_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_DISPALY_NAVBAR_STATUS, defaultKV[DefaultKey.SETTINGS_DISPALY_NAVBAR_STATUS_DEFAULT]);

    console.log(TAG + "loadDefaultSettings end");
    return;
  }

  private readDefaultFile(): string {
    console.log(TAG + "readDefaultFile start");
    let str: string = "";
    let ss;
    try {
      ss = fileio.createStreamSync(DEFAULT_JSON_FILE_PATH, "r");
      console.log(TAG + "readDefaultFile createStreamSync = " + ss);
      let buf = new ArrayBuffer(4096);
      let num = ss.readSync(buf);
      while (num) {
        console.log(TAG + "readDefaultFile readSync num = " + num + " buff = " + new Uint8Array(buf.slice(0, num)));
        str = str.concat(String.fromCharCode.apply(null, new Uint8Array(buf.slice(0, num))));
        num = ss.readSync(buf);
      }
      ss.closeSync();
      console.log(TAG + "readDefaultFile readSync = " + JSON.stringify(str));
    } catch (err) {
      console.log(TAG + "readDefaultFile readSync err" + err);
      if (ss) {
        ss.closeSync();
      }
    }
    console.log(TAG + "readDefaultFile end");
    return str;
  }

  private getDefaultSettingsKV() {
    console.log(TAG + "getDefaultSettingsKV start");
    let defaultKV = {};
    try {
      let content = this.readDefaultFile();
      if (!content) {
        console.log(TAG + "getDefaultSettingsKV readDefaultFile err! context = " + content);
        throw new Error("readfile error!")
      }
      let defaultJson = JSON.parse(content);
      console.log(TAG + "getDefaultSettingsKV parse = " + JSON.stringify(defaultJson));
      for (var index = 0; index < defaultJson.settings.length; index++) {
        defaultKV[defaultJson.settings[index].name] = defaultJson.settings[index].value;
      }
    } catch (err) {
      console.log(TAG + "getDefaultSettingsKV catch err! err = " + err);
      defaultKV = DefalutKVGlobal;
    }
    let deviceName : string = deviceinfo.marketName;
    if (deviceName.startsWith('"') && deviceName.endsWith('"')) {
      deviceName = JSON.parse(deviceName);
    }
    defaultKV[DefaultKey.SETTINGS_GENERAL_DEVICE_NAME_DEFAULT] = deviceName;
    return defaultKV;
  }
}

export default SettingsDBHelper;
