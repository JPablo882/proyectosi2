import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Avances } from './avances';

describe('Avances', () => {
  let component: Avances;
  let fixture: ComponentFixture<Avances>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Avances],
    }).compileComponents();

    fixture = TestBed.createComponent(Avances);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
