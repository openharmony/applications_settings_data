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

        import Audio from '@ohos.multimedia.audio';
        import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
        import DataShareExtensionAbility from '@ohos.application.DataShareExtensionAbility';
        import rpc from '@ohos.rpc';
        import SettingsDataConfig from '../Utils/SettingsDataConfig';
        import SettingsDBHelper from '../Utils/SettingsDBHelper';
        import { Log } from '../Utils/Log';
        import process from '@ohos.process';
        import settings from '@ohos.settings';

        let rdbStore;
        let requests:any[] = [];
        let SETTINGS_AUDIO_RINGTONE = "settings.audio.ringtone"
        let SETTINGS_AUDIO_MEDIA = "settings.audio.media"
        let SETTINGS_AUDIO_VOICE_CALL = "settings.audio.voicecall"
        let trustList: Array<String> = [
        settings.display.SCREEN_BRIGHTNESS_STATUS,
        settings.display.AUTO_SCREEN_BRIGHTNESS,
        settings.display.SCREEN_OFF_TIMEOUT
        ];

        export default class DataExtAbility extends DataShareExtensionAbility {
            onCreate(want) {

                globalThis.abilityContext = this.context;
                this.onInitialized();
            }

            onInitialized() {
                Log.info('onInitialize start');
                let context = globalThis.abilityContext;
                if (context != null) {
                    SettingsDBHelper.getInstance().getRdbStore().then((rdb: any) => {
                        rdbStore = rdb;
                        for (let i = 0; i < requests.length; i++) {
                            let opt: string = requests[i]["operation"];
                            let columns = requests[i]["columns"];
                            let predicates = requests[i]["predicates"];
                            let value = requests[i]["value"];
                            if (opt == "insert") {
                                rdbStore.insert(SettingsDataConfig.TABLE_NAME, value, function (err, ret) {
                                    Log.info('onInitialized insert ret: ' + ret);
                                });
                            } else if (opt == "query") {
                                rdbStore.query(predicates, columns, function (err, resultSet) {
                                    Log.info('onInitialized query ret: ' + JSON.stringify(resultSet));
                                });
                            } else if (opt == "update") {
                                rdbStore.update(value, predicates, function (err, ret) {
                                    Log.info('onInitialized update ret: ' + ret);
                                });
                            }
                        }
                    }).catch(err => {
                        Log.error('onInitialize failed:' + JSON.stringify(err));
                    })
                } else {
                    Log.info('onInitialize context error!');
                }
                Log.info('onInitialize end');
            }

            insert(uri, value, callback) {
                Log.info('insert keyword = ' + value[SettingsDataConfig.FIELD_KEYWORD] + ' start:' + uri);
                let rdbInsert = (GrantStatus) => {
                    if (!GrantStatus) {
                        callback(-1, 0);
                        return;
                    }
                    this.DoSystemSetting(value[SettingsDataConfig.FIELD_KEYWORD], value[SettingsDataConfig.FIELD_VALUE]);
                    if (rdbStore == null) {
                        let request = {
                            "operation": "insert", "columns": null, "predicates": null, value: value
                        };
                        Log.info('insert request = ' + JSON.stringify(request));
                        requests.push(request);
                        callback(-1, 0);
                    } else {
                        rdbStore.insert(SettingsDataConfig.TABLE_NAME, value, function (err, ret) {
                            callback(err, ret);
                            Log.info('insert result: ' + ret);
                        });
                    }
                }

                try {
                    Log.info('Start to verify permissions.');
                    this.verifyPermission(value, rdbInsert);
                } catch (err) {
                    Log.error('Insert Data error:' + JSON.stringify(err));
                    callback(-1, 0);
                }
            }

            update(uri: string, predicates, value, callback) {
                Log.info('update keyword = ' + value[SettingsDataConfig.FIELD_KEYWORD] + ' start:' + uri);
                let rdbUpData = (GrantStatus) => {
                    if (!GrantStatus) {
                        callback(-1, 0);
                        return;
                    }
                    this.DoSystemSetting(value[SettingsDataConfig.FIELD_KEYWORD], value[SettingsDataConfig.FIELD_VALUE]);
                    if (rdbStore == null) {
                        let request = {
                            "operation": "update", "columns": null, "predicates": predicates, value: value
                        };
                        Log.info('update request = ' + JSON.stringify(request));
                        requests.push(request);
                        callback(-1, 0);
                    } else {
                        rdbStore.update(SettingsDataConfig.TABLE_NAME, value, predicates, function (err, ret) {
                            callback(err, ret);
                            Log.info('update result: ' + ret);
                        });
                    }
                }
                try {
                    Log.info('Start to verify permissions.');
                    this.verifyPermission(value, rdbUpData);
                } catch (err) {
                    Log.error('upData error:' + JSON.stringify(err));
                    callback(-1, 0);
                }
            }

            delete(uri: string, predicates, callback) {
                Log.info('nothing to do');
            }

            query(uri: string, predicates, columns: Array<string>, callback) {
                Log.info( 'query start uri:' + uri);
                if (rdbStore == null) {
                    let request= {"operation":"query", "columns" : columns, "predicates" : predicates, value:""};
                    Log.info('query request = '+ JSON.stringify(request));
                    requests.push(request);
                    callback(-1, {"_napiwrapper":{}});
                } else {
                    rdbStore.query(SettingsDataConfig.TABLE_NAME, predicates, columns, function (err, resultSet) {
                        callback(err, resultSet);
                        Log.info('query result: '+ JSON.stringify(resultSet.rowCount) +'columnNames'+ JSON.stringify(resultSet.columnNames));
                    });
                }
            }

            private DoSystemSetting(settingsKey: string, settingsValue: string) {
                switch (settingsKey) {
                    case SETTINGS_AUDIO_RINGTONE:
                        try {
                            let volumeType = Audio.AudioVolumeType.RINGTONE;
                            Audio.getAudioManager().setVolume(volumeType, parseInt(settingsValue)).then(() => {
                                Log.info('settings Promise returned to indicate a successful RINGTONE setting.')
                            });
                        } catch (err) {
                            Log.info('settings RINGTONE failed error = ' + JSON.stringify(err));
                        }
                        break
                    case SETTINGS_AUDIO_MEDIA:
                        try {
                            let volumeType = Audio.AudioVolumeType.MEDIA;
                            Audio.getAudioManager().setVolume(volumeType, parseInt(settingsValue)).then(() => {
                                Log.info('settings Promise returned to indicate a successful MEDIA setting.')
                            });
                        } catch (err) {
                            Log.info('settings MEDIA failed error = ' + JSON.stringify(err));
                        }
                        break
                    case SETTINGS_AUDIO_VOICE_CALL:
                        try {
                            let volumeType = Audio.AudioVolumeType.VOICE_CALL;
                            Audio.getAudioManager().setVolume(volumeType, parseInt(settingsValue)).then(() => {
                                Log.info('settings Promise returned to indicate a successful VOICE_CALL setting.')
                            });
                        } catch (err) {
                            Log.info('settings VOICE_CALL failed error = ' + JSON.stringify(err));
                        }
                        break
                    default:
                        Log.info(settingsKey + ' key is not audio');
                        break
                }
            }

            private verifyPermission(value, callBack) {
                if (this.isTrustList(value[SettingsDataConfig.FIELD_KEYWORD]) || process.uid == rpc.IPCSkeleton.getCallingUid()) {
                    callBack(true);
                    return;
                }
                try {
                    let tokenID = rpc.IPCSkeleton.getCallingTokenId();
                    Log.info('tokenID = ' + tokenID);
                    let grantStatus = abilityAccessCtrl.createAtManager().verifyAccessToken(tokenID, "ohos.permission.MANAGE_SECURE_SETTINGS");
                    grantStatus.then(data => {
                        if (data == abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
                            Log.info('MANAGE_SECURE_SETTINGS active');
                            callBack(true);
                        } else {
                            Log.warn('MANAGE_SECURE_SETTINGS grantStatus= ' + JSON.stringify(data));
                            callBack(false);
                        }
                    }).catch((err) => {
                        Log.error('tokenID = ' + tokenID + ' verifyAccessToken is failed: ' + JSON.stringify(err));
                        callBack(false);
                    })
                } catch (err) {
                    Log.error('err = ' + JSON.stringify(err));
                    callBack(false);
                }
            }

            private isTrustList(keyWord: String): boolean {
                return trustList.includes(keyWord)
            }
        }