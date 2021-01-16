import { Injectable } from '@angular/core';

@Injectable()
export class EnvService {

    // The values that are defined here are the default values that can
    // be overridden by env.js
  
    // API url
    public apiUrl = 'defaulturl.com';
  
    // Whether or not to enable debug mode
    public enableDebug = true;
  
    constructor() {
    }
  
  }