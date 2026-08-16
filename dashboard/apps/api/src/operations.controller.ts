import { Body, Controller, Headers, HttpException, HttpStatus, Post } from "@nestjs/common";
import { IsArray, IsIn, IsOptional, IsString, Matches } from "class-validator";
import { PlatformService } from "./platform.service";

const actions=["manager.verify","project.start","project.stop","project.verify","project.backup","collection.crawl","collection.verify"] as const;
class OperationDto { @IsIn(actions) action!:typeof actions[number]; @IsOptional() @IsString() @Matches(/^\/srv\/projects\/[A-Za-z0-9._-]+$/) target?:string; @IsOptional() @IsArray() @IsString({each:true}) args?:string[]; }
@Controller("operations") export class OperationsController {
  constructor(private readonly platform:PlatformService){}
  @Post() async execute(@Body() body:OperationDto,@Headers("x-aiops-dashboard-token") token?:string,@Headers("x-aiops-actor") actor?:string){
    const expected=process.env.AIOPS_DASHBOARD_TOKEN;if(!expected||!token||token.length!==expected.length||!timingSafeEqual(token,expected))throw new HttpException("operation authorization failed",HttpStatus.UNAUTHORIZED);
    return this.platform.broker({...body,actor:actor?.slice(0,64)||"dashboard-operator"});
  }
}
function timingSafeEqual(a:string,b:string){let value=0;for(let i=0;i<a.length;i++)value|=a.charCodeAt(i)^b.charCodeAt(i);return value===0;}
