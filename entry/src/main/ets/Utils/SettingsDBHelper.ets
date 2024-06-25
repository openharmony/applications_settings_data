/**
 * Copyright (c) 2021-2023 Huawei Device Co., Ltd.
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

import common from '@ohos.app.ability.common';
import dataStorage from '@ohos.data.preferences';
import deviceInfo from '@ohos.deviceInfo';
import relationalStore from '@ohos.data.relationalStore';
import fs from '@ohos.file.fs';
import i18n from '@ohos.i18n';
import settings from '@ohos.settings';
import systemParameter from '@ohos.systemparameter';
import SettingsDataConfig from './SettingsDataConfig';
import { Log } from '../Utils/Log';
import { GlobalContext }  from './GlobalContext';
import contextConstant from '@ohos.app.ability.contextConstant';
import { TableType } from '../common/Common';

const DEFAULT_JSON_FILE_NAME : string = 'default_settings.json';
const SETTINGSDATA_PREFERENCE : string = 'SettingsDataPreference';
const SETTINGSDATA_PREFERENCE_USER : string = 'SettingsDataPreferenceUser';
const EL2_DB_PATH: string = '/data/storage/el2/database/entry/rdb/settingsdata.db'
const EMULATOR_TYPE: string = 'emulator'
interface  TIME_FORMAT_DATA {
  TIME_FORMAT_24: string ;
  TIME_FORMAT_12: string ;
}
const TIME_FORMAT: TIME_FORMAT_DATA = {
  TIME_FORMAT_24: '24',
  TIME_FORMAT_12: '12',
}
interface IContent {
  settings: Array<Map<string,string>> ;
  user: Array<Map<string,string>> ;
  userSecure: Array<Map<string,string>> ;
}

const INITIAL_KEY: string = '_CreatedTime';
const VALID_DB_LENGTH: number = 48;
const SETTINGS_CLONED_STATUS: string = 'settingsClonedStatus';

class SettingsDBHelper {
  public static readonly SHARED_TABLE_CREATE_PREFIX: string =
    `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.TABLE_NAME}`;
  // 需要在在表名后拼接当前的userid
  public static readonly CURRENT_USER_TABLE_CREATE_PREFIX: string =
    `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.USER_TABLE_NAME}_`;
  public static readonly CURRENT_SECURE_TABLE_CREATE_PREFIX: string =
    `CREATE TABLE IF NOT EXISTS ${SettingsDataConfig.SECURE_TABLE_NAME}_`;
  public static readonly TABLE_CREATE_SUFFIX = ` (${SettingsDataConfig.FIELD_ID} INTEGER PRIMARY KEY AUTOINCREMENT, ` +
    `${SettingsDataConfig.FIELD_KEYWORD} TEXT, `  +
    `${SettingsDataConfig.FIELD_VALUE} TEXT CHECK (LENGTH(VALUE)<=1000))`;

  private rdbStore?: relationalStore.RdbStore;
  private context: Context;
  private readonly DEFAULT_USER_ID: number = 100;
  private area: contextConstant.AreaMode | undefined = undefined;
  public isFirstStartup: dataStorage.ValueType = true;
  public maxUserNO: dataStorage.ValueType = 100;
  private faultOccured: boolean = false;

  private constructor() {
    this.rdbStore = undefined;
    this.context = GlobalContext.thisContext as Context;
    Log.info('context start'+ JSON.stringify(this.context));
  }

  private async emulatorParamInit(): Promise<void> {
    if (this.getProductModel() !== EMULATOR_TYPE) {
      Log.info('currently not a emulator');
      return;
    }

    let tableName: string = this.getTableName(TableType.SETTINGS, this.DEFAULT_USER_ID);
    await this.loadTableSettings('device_provisioned', '1', tableName);
    tableName = this.getTableName(TableType.USER_SECURE, this.DEFAULT_USER_ID);
    await this.loadTableSettings('basic_statement_agreed', '1', tableName);
    await this.loadTableSettings('user_setup_complete', '1', tableName);
    await this.loadTableSettings('is_ota_finished', '1', tableName);
  }

  public getProductModel(): string {
    return deviceInfo.productModel;
  }

  public getArea() {
    const dbFile = EL2_DB_PATH;
    if (this.area === undefined) {
      try {
        let stat = fs.statSync(dbFile);
        if (stat.size > VALID_DB_LENGTH) {
          this.area = contextConstant.AreaMode.EL2;
        } else {
          this.area = contextConstant.AreaMode.EL1;
        }
      } catch {
        this.area = contextConstant.AreaMode.EL1;
      }
    }
    Log.info(`Area ${this.area}`);
    return this.area;
  }

  public async initialInsert(tableName: string): Promise<void> {
    try {
      Log.info(`insert ${tableName} with key: ${tableName + INITIAL_KEY} `);
      if (this.rdbStore) {
        let ret = await this.rdbStore.insert(tableName,
          { 'KEYWORD': tableName + INITIAL_KEY, 'VALUE': new Date().toString() });
        if (ret <= 0) {
          Log.error(`insert initial key-value failed for ${tableName}`);
        }
      } else {
        Log.error(`insert initial key-value failed for ${tableName}, no rdbStore`);
        this.faultOccured = true;
      }
    } catch (e) {
      Log.error(`insert initial key-value failed for ${tableName}`);
    }
  }

  private async firstStartupConfig() : Promise<void> {
    Log.info('firstStartupConfig start');
    let storage = await dataStorage.getPreferences(this.context as Context, SETTINGSDATA_PREFERENCE);
    this.isFirstStartup = await storage.get('isFirstStartup', true);
    storage = await dataStorage.getPreferences(this.context as Context, SETTINGSDATA_PREFERENCE_USER);
    this.maxUserNO = await storage.get('MAXUSERNO', 100);
    Log.info(`firstStartupConfig isFirstStartUp = ${this.isFirstStartup} max user no: ${this.maxUserNO}`);
    // 总是创建以下三张表 if not exists
    // 创建公共数据表
    await this.rdbStore?.executeSql(SettingsDBHelper.SHARED_TABLE_CREATE_PREFIX +
    SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
    // 创建默认用户数据表
    await this.rdbStore?.executeSql(SettingsDBHelper.CURRENT_USER_TABLE_CREATE_PREFIX +
    this.DEFAULT_USER_ID + SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
    // 创建默认用户 secure 数据表
    await this.rdbStore?.executeSql(SettingsDBHelper.CURRENT_SECURE_TABLE_CREATE_PREFIX +
    this.DEFAULT_USER_ID + SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
    if (this.isFirstStartup) {
      // 推迟 this.loadDefaultSettingsData() =>after data migrate in DataExtAbility;
      await this.initialInsert(SettingsDataConfig.TABLE_NAME);
      await this.initialInsert(SettingsDataConfig.USER_TABLE_NAME + '_' + this.DEFAULT_USER_ID);
      await this.initialInsert(SettingsDataConfig.SECURE_TABLE_NAME + '_' + this.DEFAULT_USER_ID);
    }
    Log.info('firstStartupConfig end');
    return;
  }

  public async initRdbStore() {
    Log.info('call initRdbStore start');
    let  rdbStore = await relationalStore.getRdbStore(
      this.context as Context, { name: SettingsDataConfig.DB_NAME,securityLevel:1 });
    if(rdbStore){
      this.rdbStore = rdbStore;
    }


    await this.firstStartupConfig();

    Log.info('call initRdbStore end');
    return this.rdbStore;
  }

  public static getInstance(): SettingsDBHelper {
    GlobalContext.getContext().getObject('settingsDBHelper') as SettingsDBHelper;
    if(!GlobalContext.getContext().getObject('settingsDBHelper')){
      GlobalContext.getContext().setObject('settingsDBHelper', new SettingsDBHelper());
    }
    return GlobalContext.getContext().getObject('settingsDBHelper') as SettingsDBHelper;
  }

  public async getRdbStore() {
    Log.info(`getRdbStore start this.rdbStore:${this.rdbStore}`);
    if (!this.rdbStore) {
      Log.info(`initRdbStore ready to start`);
      return  await (GlobalContext.getContext().getObject('settingsDBHelper') as SettingsDBHelper).initRdbStore();
      // return await globalThis.settingsDBHelper.initRdbStore();
    }
    return this.rdbStore
  }

  public async loadTableData(content: IContent, tableType: TableType, userId: number): Promise<void> {
    if (!content) {
      Log.error('content is empty');
      return;
    }
    switch (tableType) {
      case TableType.SETTINGS:
        this.loadDefaultTaleData(content.settings, TableType.SETTINGS, userId);
        return;
      case TableType.USER:
        this.loadDefaultTaleData(content.user, TableType.USER, userId);
        return;
      case TableType.SETTINGS:
        this.loadDefaultTaleData(content.userSecure, TableType.USER_SECURE, userId);
        return;
      default:
        Log.error('invalid type');
    }
  }

  private  getTableName(tableType: TableType, userId: number): string {
    if (tableType === TableType.SETTINGS) {
      return SettingsDataConfig.TABLE_NAME;
    }
    if (tableType === TableType.USER) {
      return `${SettingsDataConfig.USER_TABLE_NAME}_${userId}`;
    }
    return `${SettingsDataConfig.SECURE_TABLE_NAME}_${userId}`;
  }

  private async loadTableSettings(key: string, value: string, tableName: string): Promise<void> {
    if (!this.rdbStore) {
      Log.error('rdbStore is null!');
      return
    }
    Log.info(`tableName: ${tableName}, key: ${key}, value: ${value}`);
    try {
      let ret = await this.rdbStore.insert(tableName, { 'KEYWORD': key, 'VALUE': value });
      if (ret >= 0) {
        Log.info(`insert into DB success; ${ret}`);
      } else {
        this.faultOccured = true;
        Log.error(`insert into DB faild; ${ret}`);
      }
    } catch (err) {
      Log.warn(`insert key ${key} failed`);
    }
  }

  public async loadUserSettings(key: string, value: string, userId: number|undefined): Promise<void> {
    if (!this.rdbStore) {
      Log.error('rdbStore is null!');
      return
    }
    Log.info('key=' + key + ' value ' + value + ' userid ' + userId);
    await this.rdbStore.insert(SettingsDataConfig.USER_TABLE_NAME + '_' + userId,
      { 'KEYWORD': key, 'VALUE': value }, (err, ret) => {
      if (err) {
        Log.error('loadGlobalSettings insert error:' + JSON.stringify(err));
      }
      Log.info('loadGlobalSettings insert ret = ' + ret);
    });
  }

  public async readDefaultFile(): Promise<Object> {
    let rawStr: string = '';
    try {
      let content: number[] = Array.from(await this.context?.resourceManager.getRawFile(DEFAULT_JSON_FILE_NAME));
      rawStr = String.fromCharCode(...Array.from(content));
    } catch (err) {
      Log.error('readDefaultFile readRawFile err' + err);
    }

    if (rawStr) {
      Log.info('readDefaultFile success');
      return JSON.parse(rawStr);
    }
    return rawStr;
  }

  private async loadDefaultSettingsData(): Promise<void> {
    if (!this.isFirstStartup) {
      Log.info('loadDefaultSettingsData exists');
      return;
    }
    Log.info('loadDefaultSettingsData start');
    try {
      let content = await this.readDefaultFile() as IContent;
      if (!content) {
        Log.error('readDefaultFile is failed!');
        return;
      }
      // 同时加载三张表，主要用于首次加载场景
      await this.loadTableData(content, TableType.SETTINGS, this.DEFAULT_USER_ID);
      await this.loadTableData(content, TableType.USER, this.DEFAULT_USER_ID);
      await this.loadTableData(content, TableType.USER_SECURE, this.DEFAULT_USER_ID);
    } catch (err) {
      Log.error('loadDefaultSettingsData catch error! err = ' + err);
    }

    let tableName: string = this.getTableName(TableType.SETTINGS, this.DEFAULT_USER_ID);
    // 初始化设备名称
    let deviceName: string = deviceInfo.marketName;
    if (deviceName.startsWith('"') && deviceName.endsWith('"')) {
      deviceName = JSON.parse(deviceName);
    }
    await this.loadTableSettings(settings.general.DEVICE_NAME, deviceName, tableName);

    // 初始化亮度值
    let defaultBrightness = systemParameter.getSync('const.display.brightness.default');
    if (defaultBrightness) {
      await this.loadTableSettings(settings.display.SCREEN_BRIGHTNESS_STATUS, defaultBrightness, tableName);
    }

    // 初始化克隆标识
    await this.loadTableSettings(SETTINGS_CLONED_STATUS, '0', tableName);

    // 适配模拟器开机不走OOBE
    await this.emulatorParamInit();

    //make sure no faultoccured, then write isFirstStartup false;
    if (this.faultOccured === false) {
      let storage = await dataStorage.getPreferences(this.context as Context, SETTINGSDATA_PREFERENCE);
      await storage.put('isFirstStartUp', false);
      await storage.flush();
      Log.info('settingsdata initial DB success. ')
    } else {
      Log.warn('settingsdata initial DB failed! Will retry possible during next startup!!!');
    }
    Log.info('loadDefaultSettingsData end');
  }
  private async loadDefaultTaleData(tableData: Array<Map<string, string>>, tableType: TableType,
                                    userID: number): Promise<void> {
    if (tableData?.length <= 0) {
      Log.error(`${tableType} table data is empty`);
      return;
    }
    let tableName: string = this.getTableName(tableType, userID);
    for (let index = 0; index < tableData.length; index++) {
      await this.loadTableSettings(tableData[index]['name'], tableData[index]['value'], tableName);
    }
  }
}

export default SettingsDBHelper;
