/**
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2023. All rights reserved.
 */

import { Log } from '../Utils/Log';
import AbilityStage from "@ohos.app.ability.AbilityStage"

export default class DataAbilityStage extends AbilityStage {
    onCreate() {
        Log.I('DataAbilityStage onCreate');
        globalThis.abilityContext = this.context;
    }
}