import { Component, ViewChild, ElementRef, AfterViewChecked, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

import { ApiService } from '../../services/api';

@Component({
  selector: 'app-chatbot',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './chatbot.html',
  styleUrl: './chatbot.scss'
})
export class ChatbotComponent implements AfterViewChecked {

  @ViewChild('chatBox') chatBox!: ElementRef;

  pregunta = '';

  mensajes: any[] = [];

  cargando = false;

  grabando = false;

  tiempoFormateado = '00:00';

  mediaRecorder!: MediaRecorder;

  audioChunks: Blob[] = [];

  private debeScrool = false;

  private timerInterval: any;

  private segundosTranscurridos = 0;

  private mediaStream: MediaStream | null = null;

  constructor(
    private api: ApiService,
    private cdr: ChangeDetectorRef,
    private sanitizer: DomSanitizer
  ){}

  convertirMarkdown(texto: string): SafeHtml {
    if (!texto) return '';

    // Primero escapar HTML para prevenir vulnerabilidades XSS
    let html = texto
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');

    // Convertir listas con viñetas que se separan por ' * ', ' - ' o que inician con '* ', '- '
    html = html.replace(/\s+[\*\-]\s+(\*\*|[a-zA-Z0-9])/g, '<br><span class="bullet-item">• </span>$1');
    html = html.replace(/(?:^|<br>)\s*[\*\-]\s+(\*\*|[a-zA-Z0-9])/g, '<br><span class="bullet-item">• </span>$1');

    // Convertir negritas (**texto** o __texto__)
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/__(.*?)__/g, '<strong>$1</strong>');

    // Convertir cursiva (*texto* o _texto_)
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');
    html = html.replace(/_(.*?)_/g, '<em>$1</em>');

    // Convertir saltos de línea (\n)
    html = html.replace(/\n/g, '<br>');

    // Limpiar saltos de línea redundantes
    html = html.replace(/(<br>){2,}/g, '<br>');

    return this.sanitizer.bypassSecurityTrustHtml(html);
  }

  ngAfterViewChecked(){
    if(this.debeScrool){
      this.scrollAlFinal();
      this.debeScrool = false;
    }
  }

  scrollAlFinal(){
    try {
      if(this.chatBox){
        this.chatBox.nativeElement.scrollTop =
          this.chatBox.nativeElement.scrollHeight;
      }
    } catch(e){}
  }

  private obtenerMensajeError(err: any): string {
    if(err.name === 'TimeoutError'){
      return 'La IA tardó demasiado en responder. Por favor intenta de nuevo.';
    }
    if(err?.error?.detail){
      return 'Error de IA: ' + err.error.detail;
    }
    if(err.status === 0){
      return 'No se pudo conectar con el servidor. Verifica que el backend esté corriendo.';
    }
    return 'Error al conectar con la IA. Intenta de nuevo.';
  }

  historialContexto: any[] = [];

  enviarPregunta(){

    if(!this.pregunta.trim() || this.cargando) return;

    const texto = this.pregunta;

    this.mensajes.push({
      tipo: 'usuario',
      texto: texto
    });

    this.historialContexto.push({
      rol: 'usuario',
      mensaje: texto
    });

    this.pregunta = '';

    this.cargando = true;
    this.debeScrool = true;

    console.log('Enviando pregunta a la IA:', texto);
    console.log('Headers de la petición:', (this.api as any).getHeaders());

    this.api.preguntarIA(texto, this.historialContexto)
    .subscribe({

      next: (resp:any) => {
        console.log('Respuesta recibida exitosamente:', resp);

        this.mensajes.push({
          tipo: 'ia',
          texto: resp.respuesta || 'La IA no generó respuesta.'
        });

        this.historialContexto.push({
          rol: 'asistente',
          mensaje: resp.respuesta
        });

        this.cargando = false;
        this.debeScrool = true;
        this.cdr.detectChanges();

      },

      error: (err) => {
        console.error('Error al consultar la IA:', err);

        this.mensajes.push({
          tipo: 'ia',
          texto: this.obtenerMensajeError(err)
        });

        this.cargando = false;
        this.debeScrool = true;
        this.cdr.detectChanges();

      }

    });

  }

  async iniciarGrabacion(){

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: true
      });

      this.mediaStream = stream;
      this.mediaRecorder = new MediaRecorder(stream);
      this.audioChunks = [];

      this.mediaRecorder.ondataavailable = (event:any) => {
        this.audioChunks.push(event.data);
      };

      this.mediaRecorder.start();

      this.grabando = true;
      this.segundosTranscurridos = 0;
      this.tiempoFormateado = '00:00';

      if (this.timerInterval) {
        clearInterval(this.timerInterval);
      }

      this.timerInterval = setInterval(() => {
        this.segundosTranscurridos++;
        const mins = Math.floor(this.segundosTranscurridos / 60);
        const secs = this.segundosTranscurridos % 60;
        this.tiempoFormateado = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        this.cdr.detectChanges();
      }, 1000);

      this.cdr.detectChanges();

    } catch (err) {
      console.error('Error al acceder al micrófono:', err);
      this.mensajes.push({
        tipo: 'ia',
        texto: '❌ No se pudo acceder al micrófono. Por favor, activa los permisos del micrófono en tu navegador.'
      });
      this.debeScrool = true;
      this.cdr.detectChanges();
    }

  }

  detenerGrabacion(){

    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }

    this.grabando = false;

    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop();
    }

    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = null;
    }

    if (this.mediaRecorder) {
      this.mediaRecorder.onstop = () => {

        const audioBlob = new Blob(
          this.audioChunks,
          {
            type: 'audio/webm'
          }
        );

        const formData = new FormData();

        formData.append(
          'audio',
          audioBlob,
          'audio.webm'
        );

        this.cargando = true;
        this.debeScrool = true;

        this.mensajes.push({
          tipo: 'usuario',
          texto: '🎤 Audio enviado'
        });

        this.cdr.detectChanges();

        this.api.preguntarAudio(formData)
        .subscribe({

          next: (resp:any) => {

            console.log(resp);

            this.mensajes.push({
              tipo: 'ia',
              texto: resp.respuesta
            });

            this.cargando = false;
            this.debeScrool = true;
            this.cdr.detectChanges();

          },

          error: (err) => {

            console.error('Error Audio IA:', err);

            this.mensajes.push({
              tipo: 'ia',
              texto: this.obtenerMensajeError(err)
            });

            this.cargando = false;
            this.debeScrool = true;
            this.cdr.detectChanges();

          }

        });

      };
    }

  }

}