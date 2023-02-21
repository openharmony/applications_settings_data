/**
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import SettingsDataConfig from '../Utils/SettingsDataConfig';
import SettingsDBHelper from '../Utils/SettingsDBHelper';
import StaticSubscriberExtensionAbility from '@ohos.application.StaticSubscriberExtensionAbility';
import { Log } from '../Utils/Log';
import ohosDataRdb from '@ohos.data.rdb';
import commonEventManager from '@ohos.commonEventManager';

const CURRENT_USER_TABLE_DROP: string = `DROP TABLE IF EXISTS ${SettingsDataConfig.USER_TABLE_NAME}_`
const TAG: string = 'UserChangeStaticSubscriber : '

export default class UserChangeStaticSubscriber extends StaticSubscriberExtensionAbility {
  async onReceiveEvent(event) {
    if (!event) {
      return
    }
    Log.I(TAG + 'onReceiveEvent, event' + JSON.stringify(event))
    let rdb: ohosDataRdb.RdbStore = await SettingsDBHelper.getInstance().getRdbStore();
    switch (event.event) {
      case commonEventManager.Support.COMMON_EVENT_USER_ADDED:
        // 创建对应用户的数据表
        await rdb.executeSql(SettingsDBHelper.CURRENT_USER_TABLE_CREATE_PREFIX + event.code + SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
        // 加载用户数据表的默认值
        try {
          let content = await SettingsDBHelper.getInstance().readDefaultFile();
          if (!content) {
            Log.E("readDefaultFile is failed!");
            return
          }
          for (var index = 0; index < content.settings.length; index++) {
            if (content.settings[index].userConfig) {
              await SettingsDBHelper.getInstance().loadUserSettings(content.settings[index].name, content.settings[index].value, event.code)
            }
          }
        } catch (err) {
          Log.E("loadDefaultSettingsData failed! err = " + err);
        }
        break
      case commonEventManager.Support.COMMON_EVENT_USER_REMOVED:
        // 删除对应用户的数据表
        rdb.executeSql(CURRENT_USER_TABLE_DROP + event.code, []);
        break
      default:
        break
    }
  }
}