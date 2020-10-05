import { TestBed, inject } from '@angular/core/testing';

import { EnvService } from './env.service';

describe('EnvService', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [EnvService]
    });
  });

  it('should be created', inject([EnvService], (service: EnvService) => {
    expect(service).toBeTruthy();
  }));
});
