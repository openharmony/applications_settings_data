/**
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import dataStorage from '@ohos.data.preferences';
import deviceInfo from '@ohos.deviceInfo';
import ohosDataRdb from '@ohos.data.rdb';
import i18n from '@ohos.i18n';
import settings from '@ohos.settings';
import systemParameter from '@ohos.systemparameter';
import SettingsDataConfig from '../Utils/SettingsDataConfig';
import { Log } from '../Utils/Log';

const DEFAULT_JSON_FILE_NAME : string = "default_settings.json";
const SETTINGSDATA_PREFERENCE : string = "SettingsDataPreference";

const TIME_FORMAT = {
  TIME_FORMAT_24: "24",
  TIME_FORMAT_12: "12",
}

class SettingsDBHelper {
  static readonly SHARED_TABLE_CREATE_PREFIX = `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.TABLE_NAME}`;
  // 需要在在表名后拼接当前的userid
  static readonly CURRENT_USER_TABLE_CREATE_PREFIX = `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.USER_TABLE_NAME}_`
  static readonly TABLE_CREATE_SUFFIX = ` (${SettingsDataConfig.FIELD_ID} INTEGER PRIMARY KEY AUTOINCREMENT, `
  + `${SettingsDataConfig.FIELD_KEYWORD} TEXT, `
  + `${SettingsDataConfig.FIELD_VALUE} TEXT CHECK (LENGTH(VALUE)<=1000))`;

  private rdbStore_: ohosDataRdb.RdbStore;
  private context_;
  private readonly DEFAULT_USER_ID: number = 100;

  private constructor() {
    this.rdbStore_ = undefined;
    this.context_ = globalThis.abilityContext;
  }

  private async firstStartupConfig() : Promise<void> {
    Log.I("firstStartupConfig start");
    let storage = await dataStorage.getPreferences(this.context_, SETTINGSDATA_PREFERENCE)
    let isFirst = await storage.get('isFirstStartUp', true)
    Log.I("firstStartupConfig isFirstStartUp = " + isFirst);
    if (isFirst) {
      // 创建公共数据表
      await this.rdbStore_.executeSql(SettingsDBHelper.SHARED_TABLE_CREATE_PREFIX + SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
      // 创建默认用户数据表
      await this.rdbStore_.executeSql(SettingsDBHelper.CURRENT_USER_TABLE_CREATE_PREFIX + this.DEFAULT_USER_ID + SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
      await storage.put('isFirstStartUp', false);
      await storage.flush();
      await this.loadDefaultSettingsData();
    }
    Log.I("firstStartupConfig end");
    return;
  }

  public async initRdbStore() {
    Log.I('call initRdbStore start');
    this.rdbStore_ = await ohosDataRdb.getRdbStore(this.context_, { name: SettingsDataConfig.DB_NAME }, 1);

    await this.firstStartupConfig();

    Log.I('call initRdbStore end');
    return this.rdbStore_;
  }

  public static getInstance() {
    if (!globalThis.settingsDBHelper) {
      globalThis.settingsDBHelper = new SettingsDBHelper();
    }
    return globalThis.settingsDBHelper;
  }

  public async getRdbStore() {
    if (!this.rdbStore_) {
      return await globalThis.settingsDBHelper.initRdbStore();
    }
    return this.rdbStore_
  }

  private async loadGlobalSettings(key, value): Promise<void> {
    if (!this.rdbStore_) {
      Log.E('rdbStore is null!');
      return
    }
    Log.I("key=" + key + " value " + value);
    await this.rdbStore_.insert(SettingsDataConfig.TABLE_NAME, { "KEYWORD": key, "VALUE": value }, (err, ret) => {
        if (err) {
          Log.E("loadGlobalSettings insert error:" + JSON.stringify(err));
        }
        Log.I("loadGlobalSettings insert ret = " + ret);
      }
    );
  }

  public async loadUserSettings(key, value, userId: number): Promise<void> {
    if (!this.rdbStore_) {
      Log.E('rdbStore is null!');
      return
    }
    Log.I("key=" + key + " value " + value + " userid " + userId);
    await this.rdbStore_.insert(SettingsDataConfig.USER_TABLE_NAME + '_' + userId,
      { "KEYWORD": key, "VALUE": value }, (err, ret) => {
      if (err) {
        Log.E("loadGlobalSettings insert error:" + JSON.stringify(err));
      }
      Log.I("loadGlobalSettings insert ret = " + ret);
    });
  }

  public async readDefaultFile() {
    let rawStr: string = "";
    try {
      let content = await this.context_.resourceManager.getRawFile(DEFAULT_JSON_FILE_NAME);
      rawStr = String.fromCharCode.apply(null, content);
    } catch (err) {
      Log.E("readDefaultFile readRawFile err" + err);
    }

    if (rawStr) {
      Log.I("readDefaultFile success");
      return JSON.parse(rawStr);
    }
    return rawStr;
  }

  private async loadDefaultSettingsData() {
    Log.I("loadDefaultSettingsData start");
    try {
      let content = await this.readDefaultFile();
      if (!content) {
        Log.E("readDefaultFile is failed!");
        return
      }
      for (var index = 0; index < content.settings.length; index++) {
        if (content.settings[index].userConfig) {
          // 加载用户数据表的默认值
          await this.loadUserSettings(content.settings[index].name, content.settings[index].value, this.DEFAULT_USER_ID)
        } else {
          // 加载公共数据表的默认值
          await this.loadGlobalSettings(content.settings[index].name, content.settings[index].value);
        }
      }
    } catch (err) {
      Log.E("loadDefaultSettingsData catch error! err = " + err);
    }

    // 初始化设备名称
    let deviceName: string = deviceInfo.marketName;
    if (deviceName.startsWith('"') && deviceName.endsWith('"')) {
      deviceName = JSON.parse(deviceName);
    }
    await this.loadGlobalSettings(settings.general.DEVICE_NAME, deviceName);

    // 初始化24小时制
    await this.loadGlobalSettings(settings.date.TIME_FORMAT, i18n.is24HourClock() ? TIME_FORMAT.TIME_FORMAT_24 : TIME_FORMAT.TIME_FORMAT_12);

    // 初始化亮度值
    let defaultBrightness = systemParameter.getSync('const.display.brightness.default');
    if (defaultBrightness) {
      await this.loadGlobalSettings(settings.display.SCREEN_BRIGHTNESS_STATUS, defaultBrightness);
    }
    Log.I("loadDefaultSettingsData end");
  }
}

export default SettingsDBHelper;
