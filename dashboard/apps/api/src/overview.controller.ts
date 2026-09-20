import { Controller, Get, UseGuards } from "@nestjs/common";
import { PlatformService } from "./platform.service";
import { WorkspaceAuthGuard } from "./auth.service";
@Controller("overview") @UseGuards(WorkspaceAuthGuard) export class OverviewController {constructor(private readonly platform:PlatformService){} @Get() async overview(){const [telemetry,projects]=await Promise.all([this.platform.telemetry(),this.platform.projects()]);return {...telemetry,projects};}}
