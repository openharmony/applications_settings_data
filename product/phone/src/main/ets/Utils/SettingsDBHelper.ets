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
import deviceinfo from '@ohos.deviceInfo';
import fileio from '@ohos.fileio';
import ohosDataRdb from '@ohos.data.rdb';
import resourceManager from '@ohos.resourceManager';
import i18n from '@ohos.i18n';
import settings from '@ohos.settings';
import systemParameter from '@ohos.systemparameter';
import SettingsDataConfig from '../Utils/SettingsDataConfig';

let DDL_TABLE_CREATE = `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.TABLE_NAME} (`
+ `${SettingsDataConfig.FIELD_ID} INTEGER PRIMARY KEY AUTOINCREMENT, `
+ `KEYWORD TEXT, `
+ `VALUE TEXT CHECK (LENGTH(VALUE)<=1000))`;

const DEFAULT_JSON_FILE_NAME: string = "default_settings.json";
const SETTINGSDATA_PREFERENCE: string = "SettingsDataPreference";

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

const TIME_FORMAT = {
  TIME_FORMAT_24: "24",
  TIME_FORMAT_12: "12",
}

let TAG = "SettingsDBHelper ";

class SettingsDBHelper {
  private firstStartupFlag: boolean;
  private rdbStore_;
  private context_;
  private static instance_: SettingsDBHelper;

  private constructor() {
    this.firstStartupFlag = false;
    this.rdbStore_ = undefined;
    this.context_ = globalThis.abilityContext;
    console.log(TAG + 'call construstor');
  }

  private async firstStartupConfig(): Promise<void> {
    console.log(TAG + "firstStartupConfig start");
    let path: string = await this.context_.getFilesDir();
    let storage = await data_storage.getStorage(path + SETTINGSDATA_PREFERENCE)
    console.log(TAG + "firstStartupConfig getStorage = " + storage);
    let isExist = await storage.has('isFirstStartUp')
    console.log(TAG + "firstStartupConfig has isFirstStartUp = " + isExist);
    if (!isExist) {
      console.info(TAG + "The key of isFirstStartUp is not contained.")
      console.log(TAG + "firstStartupConfig put start");
      await storage.put('isFirstStartUp', 'true');
      console.log(TAG + "firstStartupConfig flush start");
      await storage.flush();
      console.log(TAG + "firstStartupConfig flush end");
      this.firstStartupFlag = true;
    } else {
      let startup = await storage.get('isFirstStartUp', 'null');
      if (startup != 'true') {
        console.log(TAG + "firstStartupConfig get startup = " + startup);
        this.firstStartupFlag = true;
      }
    }
    console.log(TAG + "firstStartupConfig end");
    return;
  }

  public async initRdbStore() {
    console.log(TAG + 'call initRdbStore start');
    this.rdbStore_ = await ohosDataRdb.getRdbStore(this.context_, { name: SettingsDataConfig.DB_NAME }, 1);
    console.log(TAG + 'call initRdbStore, rdbStore_ = ' + this.rdbStore_);

    console.log(TAG + "initRdbStore executeSql");
    await this.rdbStore_.executeSql(DDL_TABLE_CREATE, []);

    console.log(TAG + 'getRdbStore firstStartupConfig');
    await this.firstStartupConfig();

    if (this.firstStartupFlag) {
      console.log(TAG + 'initRdbStore getDefaultSettingsKV');
      let defaultKV = await this.getDefaultSettingsKV();
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
      settings.display.SCREEN_BRIGHTNESS_STATUS, defaultKV[DefaultKey.SETTINGS_SCREEN_BRIGHTNESS_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      settings.date.TIME_FORMAT, defaultKV[DefaultKey.SETTINGS_TIME_FORMAT_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_AUDIO_RINGTONE, defaultKV[DefaultKey.SETTINGS_AUDIO_RINGTONE_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_AUDIO_MEDIA, defaultKV[DefaultKey.SETTINGS_AUDIO_MEDIA_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_AUDIO_VOICE_CALL, defaultKV[DefaultKey.SETTINGS_AUDIO_VOICE_CALL_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      settings.general.DEVICE_NAME, defaultKV[DefaultKey.SETTINGS_GENERAL_DEVICE_NAME_DEFAULT]);

    await this.loadSettings(this.rdbStore_,
      SettingsKey.SETTINGS_DISPALY_NAVBAR_STATUS, defaultKV[DefaultKey.SETTINGS_DISPALY_NAVBAR_STATUS_DEFAULT]);

    console.log(TAG + "loadDefaultSettings end");
    return;
  }

  private async readDefaultFile(): Promise<string> {
    console.log(TAG + "readDefaultFile start");
    let rawStr: string = "";
    try {
      let resManager = await resourceManager.getResourceManager();
      console.log("readDefaultFile resManager=" + resManager);
      let content = await resManager.getRawFile(DEFAULT_JSON_FILE_NAME);
      rawStr = String.fromCharCode.apply(null, content);
    } catch (err) {
      console.log(TAG + "readDefaultFile readRawFile err" + err);
    }
    console.log(TAG + "readDefaultFile end");
    return rawStr;
  }

  private async getDefaultSettingsKV() {
    console.log(TAG + "getDefaultSettingsKV start");
    let defaultKV = {};
    try {
      let content: string = await this.readDefaultFile();
      if (!content) {
        console.log(TAG + "getDefaultSettingsKV readDefaultFile err! content = " + content);
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
    let deviceName: string = deviceinfo.marketName;
    if (deviceName.startsWith('"') && deviceName.endsWith('"')) {
      deviceName = JSON.parse(deviceName);
    }
    defaultKV[DefaultKey.SETTINGS_GENERAL_DEVICE_NAME_DEFAULT] = deviceName;

    if (i18n.is24HourClock()) {
      defaultKV[DefaultKey.SETTINGS_TIME_FORMAT_DEFAULT] = TIME_FORMAT.TIME_FORMAT_24;
    } else {
      defaultKV[DefaultKey.SETTINGS_TIME_FORMAT_DEFAULT] = TIME_FORMAT.TIME_FORMAT_12;
    }

    let defaultBrightness = systemParameter.getSync('const.display.brightness.default');
    if (defaultBrightness.length > 0) {
      defaultKV[DefaultKey.SETTINGS_SCREEN_BRIGHTNESS_DEFAULT] = defaultBrightness;
    }
    return defaultKV;
  }
}

export default SettingsDBHelper;
