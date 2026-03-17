import 'dart:async';
import 'dart:math'; // ¡Añadimos esta librería para los números aleatorios!
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Juego Acelerómetro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const JuegoPage(),
    );
  }
}

class JuegoPage extends StatefulWidget {
  const JuegoPage({super.key});

  @override
  State<JuegoPage> createState() => _JuegoPageState();
}

class _JuegoPageState extends State<JuegoPage> {
  StreamSubscription<AccelerometerEvent>? _acelerometroSub;
  Timer? _gameLoop;

  double _accelX = 0.0;
  double _accelY = 0.0;

  double posX = 50.0;
  double posY = 50.0;
  final double pinguiSize = 50.0; 

  double screenWidth = 0.0;
  double screenHeight = 0.0;

  bool enJuego = false; 
  bool nivelGenerado = false; // Nos avisa si ya creamos el mapa actual

  // Ahora empezamos con la meta vacía y sin obstáculos
  Rect meta = Rect.zero;
  List<Rect> obstaculos = [];
  final int cantidadTiburones = 7; // Puedes subir este número para más dificultad

  @override
  void initState() {
    super.initState();
    iniciarSensores();
    iniciarJuegoLoop();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      mostrarMensajeInicio();
    });
  }

  // --- NUEVA FUNCIÓN: GENERADOR DE NIVELES ---
  void generarNivelAleatorio(double width, double height) {
    final random = Random();
    
    // 1. Generar la meta en la parte inferior (último 30% de la pantalla)
    double metaMinY = height * 0.70; // Empieza al 70% de la pantalla
    double metaMaxY = height - 70;   // Menos el tamaño de la meta para que no se salga
    double metaY = metaMinY + random.nextDouble() * (metaMaxY - metaMinY);
    double metaX = random.nextDouble() * (width - 70);
    
    meta = Rect.fromLTWH(metaX, metaY, 70, 70);

    // 2. Generar tiburones aleatorios
    obstaculos.clear();
    for (int i = 0; i < cantidadTiburones; i++) {
      Rect nuevoTiburon;
      bool posicionInvalida;

      // Usamos un bucle "do-while" para buscar una posición segura.
      // Si el tiburón cae encima de Pingüi o de la meta, lo volvemos a intentar.
      do {
        double obsX = random.nextDouble() * (width - 50);
        double obsY = random.nextDouble() * (height - 50);
        nuevoTiburon = Rect.fromLTWH(obsX, obsY, 50, 50);

        // Área segura de inicio (arriba a la izquierda)
        Rect zonaSeguraInicio = const Rect.fromLTWH(0, 0, 150, 150);
        
        // Comprobamos si choca con el inicio o tapando totalmente la meta
        bool tapaInicio = nuevoTiburon.overlaps(zonaSeguraInicio);
        bool tapaMeta = nuevoTiburon.overlaps(meta.inflate(20)); // "Inflamos" la meta para dejarle espacio

        posicionInvalida = tapaInicio || tapaMeta;
      } while (posicionInvalida); // Repetir si es inválida

      obstaculos.add(nuevoTiburon);
    }
  }

  void mostrarMensajeInicio() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("¡Bienvenido!"),
          content: const Text("Inclina tu celular para mover a Pingüi. Llega a la meta y ten cuidado con los tiburones."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  enJuego = true; 
                });
              },
              child: const Text("¡Empezar a jugar!"),
            )
          ],
        );
      },
    );
  }

  void iniciarSensores() {
    _acelerometroSub = accelerometerEventStream().listen((event) {
      _accelX = event.x;
      _accelY = event.y;
    });
  }

  void iniciarJuegoLoop() {
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!enJuego) return; 
      actualizarPosicion();
    });
  }

  void actualizarPosicion() {
    setState(() {
      posX -= _accelX * 2.0; 
      posY += _accelY * 2.0;

      if (posX < 0) posX = 0;
      if (posX > screenWidth - pinguiSize) posX = screenWidth - pinguiSize;
      if (posY < 0) posY = 0;
      if (posY > screenHeight - pinguiSize) posY = screenHeight - pinguiSize;

      Rect rectVisualPingui = Rect.fromLTWH(posX, posY, pinguiSize, pinguiSize);
      Rect hitboxPingui = rectVisualPingui.deflate(6); 

      Rect hitboxMeta = meta.deflate(15); 

      if (hitboxPingui.overlaps(hitboxMeta)) {
        terminarJuego("¡Ganaste! Llegaste a la meta.");
      }

      for (Rect obs in obstaculos) {
        Rect hitboxObstaculo = obs.deflate(10); 
        if (hitboxPingui.overlaps(hitboxObstaculo)) {
          terminarJuego("¡Ups! Un tiburón te ha atrapado.");
        }
      }
    });
  }

  void terminarJuego(String msj) {
    enJuego = false; 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(msj),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                reiniciarJuego();
              },
              child: const Text("Jugar de nuevo"),
            )
          ],
        );
      },
    );
  }

  void reiniciarJuego() {
    setState(() {
      posX = 50.0;
      posY = 50.0;
      nivelGenerado = false; // ¡CLAVE! Esto forzará a crear un nuevo mapa
      enJuego = true; 
    });
  }

  @override
  void dispose() {
    _acelerometroSub?.cancel();
    _gameLoop?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guía al pingüino'),
        backgroundColor: Colors.deepOrange,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          screenHeight = constraints.maxHeight;
          screenWidth = constraints.maxWidth;

          // Si el nivel no se ha generado (inicio del juego o reinicio), lo creamos aquí
          if (!nivelGenerado && screenWidth > 0) {
            generarNivelAleatorio(screenWidth, screenHeight);
            nivelGenerado = true;
          }

          return Container(
            color: Colors.amber[100],
            child: Stack(
              children: [
                Positioned(
                  left: meta.left,
                  top: meta.top,
                  width: meta.width,
                  height: meta.height,
                  child: Image.asset('assets/meta.png', fit: BoxFit.contain),
                ),

                ...obstaculos.map((obs) {
                  return Positioned(
                    left: obs.left,
                    top: obs.top,
                    width: obs.width,
                    height: obs.height,
                    child: Image.asset('assets/tiburon.png', fit: BoxFit.contain),
                  );
                }),

                Positioned(
                  left: posX,
                  top: posY,
                  width: pinguiSize,
                  height: pinguiSize,
                  child: Image.asset('assets/pingui.png', fit: BoxFit.contain),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}