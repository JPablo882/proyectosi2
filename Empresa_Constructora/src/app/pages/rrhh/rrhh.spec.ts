import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Rrhh } from './rrhh';

describe('Rrhh', () => {
  let component: Rrhh;
  let fixture: ComponentFixture<Rrhh>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Rrhh],
    }).compileComponents();

    fixture = TestBed.createComponent(Rrhh);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
