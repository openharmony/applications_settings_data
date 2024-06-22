/**
 * Copyright (c) 2021-2024 Huawei Device Co., Ltd.
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
import StaticSubscriberExtensionAbility from '@ohos.application.StaticSubscriberExtensionAbility';
import commonEventManager from '@ohos.commonEventManager';
import { Log, CommonEventData} from '../Utils/Log';
import SettingsDataConfig from '../Utils/SettingsDataConfig';
import SettingsDBHelper from '../Utils/SettingsDBHelper';
import { IContent, TableType } from '../common/Common';
import { GlobalContext } from '../Utils/GlobalContext';

const CURRENT_USER_TABLE_DROP: string = `DROP TABLE IF EXISTS ${SettingsDataConfig.USER_TABLE_NAME}_`;
const CURRENT_SECURE_USER_TABLE_DROP: string = `DROP TABLE IF EXISTS ${SettingsDataConfig.SECURE_TABLE_NAME}_`;
const TAG: string = 'UserChangeStaticSubscriber : '

export default class UserChangeStaticSubscriber extends StaticSubscriberExtensionAbility {
  private init() {
    Log.info('UserChangeStaticSubscriber start!')
    GlobalContext.getContext().setObject('abilityContext', this.context);
    this.context.area = SettingsDBHelper.getInstance().getArea();
  }
  async onReceiveEvent(event: CommonEventData) {
    if (!event || event.code) {
      Log.error('invalid parameters')
      return;
    }
    Log.info(`onReceiveEvent, event: ${event.event}, userId: ${event.code}`);

    this.init();
    let rdb = await SettingsDBHelper.getInstance().getRdbStore();
    switch (event.event) {
      case commonEventManager.Support.COMMON_EVENT_USER_ADDED:
        // 创建对应用户的数据表
        await rdb?.executeSql(SettingsDBHelper.CURRENT_USER_TABLE_CREATE_PREFIX + event.code +
        SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
        await rdb?.executeSql(SettingsDBHelper.CURRENT_SECURE_TABLE_CREATE_PREFIX + event.code +
        SettingsDBHelper.TABLE_CREATE_SUFFIX, []);
        Log.info('creat settings data table success!')
        // 加载用户数据表的默认值
        try {
          let content = await SettingsDBHelper.getInstance().readDefaultFile() as IContent;
          if (!content) {
            Log.error('readDefaultFile is failed!');
            return
          }
          // 初始化用户表数据
          await SettingsDBHelper.getInstance().initialInsert(SettingsDataConfig.USER_TABLE_NAME + '_' + event.code);
          await SettingsDBHelper.getInstance().initialInsert(SettingsDataConfig.SECURE_TABLE_NAME + '_' + event.code);
          // 用户数据表包含USER、USER_SECURE
          await SettingsDBHelper.getInstance().loadTableData({ settings: content.settings,
            user: content.user,
            userSecure: content.userSecure }, TableType.USER, event.code as number);
          await SettingsDBHelper.getInstance().loadTableData({ settings: content.settings,
            user: content.user,
            userSecure: content.userSecure }, TableType.USER_SECURE, event.code as number);
        } catch (err) {
          Log.error('loadDefaultSettingsData failed! err = ' + err);
        }
        break
      case commonEventManager.Support.COMMON_EVENT_USER_REMOVED:
        // 删除对应用户的数据表
        rdb?.executeSql(CURRENT_USER_TABLE_DROP + event.code, []);
        rdb?.executeSql(CURRENT_SECURE_USER_TABLE_DROP + event.code, []);
        break
      default:
        break
    }
  }
}