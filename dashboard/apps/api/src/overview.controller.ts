import { Controller, Get } from "@nestjs/common";
import { PlatformService } from "./platform.service";
@Controller("overview") export class OverviewController {constructor(private readonly platform:PlatformService){} @Get() async overview(){const [telemetry,projects]=await Promise.all([this.platform.telemetry(),this.platform.projects()]);return {...telemetry,projects};}}
