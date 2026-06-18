// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ✅ Rutina de enrutamiento estático limpia. Cero inyecciones.
  void _enrutarOperador(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF003366), Color(0xFF005A9C)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450), 
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: Colors.white.withOpacity(0.98),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircleAvatar(
                              radius: 45,
                              backgroundColor: Color(0xFF005A9C),
                              child: Icon(Icons.shield_outlined, size: 50, color: Colors.white),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'ACCESO A SISTEMA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF003366),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Campo Correo
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Correo Institucional',
                                labelStyle: const TextStyle(color: Colors.black87),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black54, width: 1.5),
                                ),
                                prefixIcon: const Icon(Icons.email_outlined, color: Colors.black),
                              ),
                              validator: (value) => value!.isEmpty ? 'Campo obligatorio' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo Código
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                labelText: 'Código de Operador',
                                labelStyle: const TextStyle(color: Colors.black87),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black54, width: 1.5),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline, color: Colors.black),
                              ),
                              validator: (value) => value!.isEmpty ? 'Campo obligatorio' : null,
                            ),
                            const SizedBox(height: 32),

                            BlocConsumer<AuthBloc, AuthState>(
                              listener: (context, state) {
                                if (state is AuthError) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
                                  );
                                } else if (state is Authenticated) {
                                  // ✅ Aquí estaba el error en tu código. Llamada limpia sin inyectar parámetros.
                                  _enrutarOperador(context);
                                }
                              },
                              builder: (context, state) {
                                if (state is AuthLoading) {
                                  return const CircularProgressIndicator();
                                }
                                return SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_formKey.currentState!.validate()) {
                                        context.read<AuthBloc>().add(IniciarSesionEvent(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text.trim(),
                                        ));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF005A9C),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('INGRESAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}