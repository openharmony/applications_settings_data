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
    Log.info(TAG + 'onReceiveEvent, event' + JSON.stringify(event))
    let rdb: ohosDataRdb.RdbStore = await SettingsDBHelper.getInstance().getRdbStore();
    switch (event.event) {
      case commonEventManager.Support.COMMON_EVENT_USER_ADDED:
        // 创建对应用户的数据表
        await rdb.executeSql(SettingsDBHelper.CURRENT_USER_TABLE_CREATE_PREFIX + event.code + SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
        // 加载用户数据表的默认值
        try {
          let content = await SettingsDBHelper.getInstance().readDefaultFile();
          if (!content) {
            Log.error("readDefaultFile is failed!");
            return
          }
          for (var index = 0; index < content.settings.length; index++) {
            if (content.settings[index].userConfig) {
              await SettingsDBHelper.getInstance().loadUserSettings(content.settings[index].name, content.settings[index].value, event.code)
            }
          }
        } catch (err) {
          Log.error("loadDefaultSettingsData failed! err = " + err);
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