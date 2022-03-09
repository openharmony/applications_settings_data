/**
 * @file Describe the file
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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
import Brightness from '@ohos.brightness';
import dataAbility from '@ohos.data.dataability';
import SettingsDataConfig from '../Utils/SettingsDataConfig';
import SettingsDBHelper from '../Utils/SettingsDBHelper';

let TAG = 'SettingsData ';
let rdbStore;
let requests:any[] = [];

function DoSystemSetting(value) {
    switch (value["KEYWORD"]) {
        case SettingsDataConfig.SettingsKey.SETTINGS_SCREEN_BRIGHTNESS:
        {
            try {
                console.log(TAG + 'settings Brightness start')
                Brightness.setValue(parseInt(value["VALUE"]));
                console.log(TAG + 'settings Brightness returned to indicate a successful Brightness setting.')
            } catch (err) {
                console.log(TAG + 'settings Brightness failed error = ' + JSON.stringify(err));
            }
        }break
        case SettingsDataConfig.SettingsKey.SETTINGS_AUDIO_RINGTONE:
        {
            try {
                let volumeType = Audio.AudioVolumeType.RINGTONE;
                console.log(TAG + 'settings RINGTONE start')
                Audio.getAudioManager().setVolume(volumeType, parseInt(value["VALUE"])).then(() => {
                    console.log(TAG + 'settings Promise returned to indicate a successful RINGTONE setting.')
                });
            } catch (err) {
                console.log(TAG + 'settings RINGTONE failed error = ' + JSON.stringify(err));
            }
        }break
        case SettingsDataConfig.SettingsKey.SETTINGS_AUDIO_MEDIA:
        {
            try {
                let volumeType = Audio.AudioVolumeType.MEDIA;
                console.log(TAG + 'settings MEDIA start')
                Audio.getAudioManager().setVolume(volumeType, parseInt(value["VALUE"])).then(() => {
                    console.log(TAG + 'settings Promise returned to indicate a successful MEDIA setting.')
                });
            } catch (err) {
                console.log(TAG + 'settings MEDIA failed error = ' + JSON.stringify(err));
            }
        }break
        case SettingsDataConfig.SettingsKey.SETTINGS_AUDIO_VOICE_CALL:
        {
            try {
                let volumeType = Audio.AudioVolumeType.VOICE_CALL;
                console.log(TAG + 'settings VOICE_CALL start')
                Audio.getAudioManager().setVolume(volumeType, parseInt(value["VALUE"])).then(() => {
                    console.log(TAG + 'settings Promise returned to indicate a successful VOICE_CALL setting.')
                });
            } catch (err) {
                console.log(TAG + 'settings VOICE_CALL failed error = ' + JSON.stringify(err));
            }
        }break
        default :
        {
            console.log(TAG + value["KEYWORD"]+' key is not brightness or audio');
        }
    }
}

export default {
    onInitialized(abilityInfo) {
        console.log(TAG + 'onInitialize start');
        SettingsDBHelper.getInstance().getRdbStore().then((rdb : any)=>{
            console.log(TAG+ " onInitialized rdb：" + rdb);
            rdbStore = rdb;
            console.log(TAG+ " onInitialized requests：" + JSON.stringify(requests));
            for(let i = 0; i < requests.length; i++) {
                let opt : string = requests[i]["operation"];
                let columns = requests[i]["columns"];
                let predicates = requests[i]["predicates"];
                let value = requests[i]["value"];
                if (opt == "insert") {
                    rdbStore.insert(SettingsDataConfig.TABLE_NAME, value, function (err, ret) {
                        console.log(TAG + 'onInitialized insert ret: ' + ret);
                    });
                } else if (opt == "query") {
                    let rdbPredicates = dataAbility.createRdbPredicates(SettingsDataConfig.TABLE_NAME, predicates);
                    rdbStore.query(rdbPredicates, columns, function (err, resultSet) {
                        console.log(TAG + 'onInitialized query ret: ' + JSON.stringify(resultSet));
                    });
                } else if (opt == "update") {
                    let rdbPredicates = dataAbility.createRdbPredicates(SettingsDataConfig.TABLE_NAME, predicates);
                    rdbStore.update(value, rdbPredicates, function (err, ret) {
                        console.log(TAG + 'onInitialized update ret: ' + ret);
                    });
                }
            }
        }).catch(err => {
            console.log(TAG + 'onInitialize failed');
        })
        console.log(TAG + 'onInitialize end');
    },

    insert(uri, value, callback) {
        console.log(TAG + 'insert keyword = ' + value["KEYWORD"] + ' start:' + uri);
        DoSystemSetting(value);
        if (rdbStore == null) {
            let request= {"operation":"insert", "columns" : null, "predicates" : null, value:value};
            console.log(TAG + 'insert request = '+ JSON.stringify(request));
            requests.push(request);
            callback(-1, 0);
        } else {
            rdbStore.insert(SettingsDataConfig.TABLE_NAME, value, function (err, ret) {
                console.log(TAG + 'insert before callback ');
                callback(err, ret);
                console.log(TAG + 'insert after callback ');
                console.log(TAG + 'insert result: ' + ret);
            });
        }
    },

    query(uri, columns, predicates, callback) {
        console.log(TAG + 'query start uri:' + uri);
        if (rdbStore == null) {
            let request= {"operation":"query", "columns" : columns, "predicates" : predicates, value:""};
            console.log(TAG + 'query request = '+ JSON.stringify(request));
            requests.push(request);
            callback(-1, {"_napiwrapper":{}});
        } else {
            let rdbPredicates = dataAbility.createRdbPredicates(SettingsDataConfig.TABLE_NAME, predicates);
            rdbStore.query(rdbPredicates, columns, function (err, resultSet) {
                console.log(TAG + 'query before callback err:' + JSON.stringify(err) + " ResultSet" + JSON.stringify(resultSet));
                callback(err, resultSet);
                console.log(TAG + 'query after callback ');
                console.log(TAG + 'query result: '+ JSON.stringify(resultSet));
            });
        }
    },

    update(uri, value, predicates, callback) {
        console.log(TAG + 'update keyword = ' + value["KEYWORD"] + ' start:' + uri);
        DoSystemSetting(value);
        if (rdbStore == null) {
            let request = {"operation":"update", "columns" : null, "predicates" : predicates, value : value};
            console.log(TAG + 'update request = '+ JSON.stringify(request));
            requests.push(request);
            callback(-1, 0);
        } else {
            let rdbPredicates = dataAbility.createRdbPredicates(SettingsDataConfig.TABLE_NAME, predicates);
            rdbStore.update(value, rdbPredicates, function (err, ret) {
                console.log(TAG + 'update before callback ' + JSON.stringify(err));
                callback(err, ret);
                console.log(TAG + 'update after callback ' + JSON.stringify(ret));
                console.log(TAG + 'update result: ' + ret);
            });
        }

    }
};
