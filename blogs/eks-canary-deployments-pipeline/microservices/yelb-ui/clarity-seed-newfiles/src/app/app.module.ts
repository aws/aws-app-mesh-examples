import { BrowserAnimationsModule } from "@angular/platform-browser/animations";
import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { environment } from '../environments/environment';
import { EnvServiceProvider } from './env.service.provider';
import { FormsModule } from '@angular/forms';
import { HttpModule } from '@angular/http';
import {NgxChartsModule} from '@swimlane/ngx-charts';
import { ClarityModule } from 'clarity-angular';
import { AppComponent } from './app.component';
import { ROUTING } from "./app.routing";

@NgModule({
    declarations: [
        AppComponent
    ],
    imports: [
        BrowserAnimationsModule,
        BrowserModule,
        FormsModule,
        HttpModule,
        NgxChartsModule,
        ClarityModule.forRoot(),
        ROUTING
    ],
    providers: [EnvServiceProvider],
    bootstrap: [AppComponent]
})
export class AppModule {
}
