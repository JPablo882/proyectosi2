import { ComponentFixture, TestBed } from '@angular/core/testing';

import { RegistroEmpresa } from './registro-empresa';

describe('RegistroEmpresa', () => {
  let component: RegistroEmpresa;
  let fixture: ComponentFixture<RegistroEmpresa>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RegistroEmpresa],
    }).compileComponents();

    fixture = TestBed.createComponent(RegistroEmpresa);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
