import 'package:eventually/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

//En la parte superior podemos observar los paquetes importados necesarios para el funcionamiento e incluso la conexión con la base de datos
//A continuación podemos ver una funcion que genera la conexión necesaria con la base de datos para iniciar sesión de forma asincrona sin ningún problema
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

//La clase MyApp se encargará de darle una definición de entrada para la aplicación
class MyApp extends StatelessWidget {
  const MyApp({super.key});
//ya todo el apartado del widget será la estructura de entrada que se tendrá en la aplicación
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Eventually',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: WelcomePage(),
      ),
    );
  }
}

//La clase MyAppState se encargará de almacenar la información importante del usuario al igual que definir estados en los cuales este la aplicación
//Al igual que estados en los que este el usuario, como su definción de rol, email, nombre y apellido, al igual que estar autentificado
class MyAppState extends ChangeNotifier {
  bool isAuthenticated = false;
  User? user;
  String? userName;
  String? userLastName;
  String? userRole;
  String? get userEmail => user?.email;

//En este apartado definimos la función que nos dará la opción de logearnos cuando estemos autentificados
  Future<void> login(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      isAuthenticated = true;
      user = FirebaseAuth.instance.currentUser;
      await fetchUserData(); // esperamos los datos del usuario para cargarlos después del login
      notifyListeners();
    } catch (e) {
      isAuthenticated =
          false; //en caso no estar autentificado le saldrá un error
      notifyListeners();
      print("Error de inicio de sesión: ${e.toString()}");
    }
  }

//En este apartado difinimos el registro y los parametros que recibirá
  Future<bool> register(String email, String password, String nombre,
      String apellido, String role) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      user = userCredential.user;
      isAuthenticated = true;

      // Guadramos la información en la base de datos con un nombre de campo como users
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'role': role,
      });

      // Asignar los valores de registro al estado
      userName = nombre;
      userLastName = apellido;
      userRole = role;

      return true; // Retornará verdadero cuando el registro este completado
    } catch (e) {
      print("Error de registro: ${e.toString()}");
      isAuthenticated = false;
      return false; // Registro fallido si le falta algún campo por llenar
    } finally {
      notifyListeners();
    }
  }

//Esto permite mostrar y modificar la información del usuario en tiempo real
  Future<void> fetchUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      userName = userDoc['nombre'];
      userLastName = userDoc['apellido'];
      userRole = userDoc['role'];
      notifyListeners();
    }
  }

//Definimos la función para cuando queramos desloguearnos
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    isAuthenticated = false;
    user = null;
    userName = null;
    userLastName = null;
    userRole = null;
    notifyListeners();
  }

//Definimos la función para que el usuario desee cambiar su rol y se reflejen los cambios en la base de datos
  Future<void> updateUserRole(
      String email, String password, String? newRole) async {
    try {
      // Autenticar al usuario con el correo y la contraseña
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user!.reauthenticateWithCredential(credential);

      // Actualizar el rol en la base de datos
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'role': newRole});

      // Actualizar el rol en el estado de la aplicación
      userRole = newRole;
      notifyListeners();
    } catch (e) {
      print("Error al actualizar el rol: $e");
      rethrow; //en tal caso de equivocarse al verificar el cambio de rol le saldrá en error
    }
  }

//Definimos la función para borrar la cuenta del usuario unicamente con la confirmación de la contraseña de inicio de sesión
  Future<void> deleteAccount(String password) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );
      await user!.reauthenticateWithCredential(credential);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .delete();
      await user!.delete();
      user = null;
      isAuthenticated = false;
      userName = null;
      userLastName = null;
      userRole = null;
      notifyListeners();
    } catch (e) {
      //Si se equivoca con la inserción de la contraseña le saldrá el error
      print("Error eliminando la cuenta: ${e.toString()}");
    }
  }
}

//La clase WelcomePage se encargará de mostrar la página inicial con los botones de inicio de sesión y Registrarse
class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              color: Colors.deepPurple,
              child: Text(
                'eventually',
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'BIENVENIDO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Icon(
              Icons.account_circle,
              color: Colors.deepPurple,
              size: 100,
            ),
            SizedBox(
                height:
                    20), //Definimos la estructura del botón de inicio de sesión como colores, forma y la vinculación a la página que le corresponde
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              icon: Icon(Icons.login, color: Colors.deepPurple),
              label: Text(
                'INICIAR SESIÓN',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
            SizedBox(
                height:
                    10), //Aplicamos la misma estructura con el botón de registro
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              icon: Icon(Icons.person_add, color: Colors.deepPurple),
              label: Text(
                'REGISTRARME',
                style: TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Aca definimos la página principal como statefulwidget ya que seria un apartado al que se accede al cumplir un requisito
class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => HomePageState();
}

//A continuación definicmos toda la estructura del homepage como sus restricciones de acceso dependiendo del rol elegido por el usuario
class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<MyAppState>(context);

    void checkAccess(String feature, Function allowedAction) {
      bool hasAccess = true;

      // Configurar las restricciones de acceso por rol
      if (appState.userRole == 'Participant' &&
          (feature == 'Publicaciones' || feature == 'Reportes')) {
        hasAccess = false;
      } else if (appState.userRole == 'Organizer' &&
          feature == 'Publicaciones') {
        hasAccess = false;
      } else if (appState.userRole == 'Admin' &&
          (feature == 'Eventos' || feature == 'Reportes')) {
        hasAccess = false;
      }

      if (hasAccess) {
        allowedAction();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No tienes acceso a $feature debido a tu rol.'),
          ),
        );
      }
    }

//Acá creamos la pantalla de cerrar sesión si el usuario va hacia atras en el homepage
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Cerrar sesión'),
                  content: Text('¿Deseas cerrar sesión?'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        appState.logout();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => WelcomePage()),
                        );
                      },
                      child: Text('Cerrar sesión'),
                    ),
                  ],
                );
              },
            );
          },
        ), //A continuación es todo los realcionado al diseño del homepage más los botones para acceder a cada funcionaliddad
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 20),
            if (appState.userName != null &&
                appState.userLastName != null &&
                appState.userRole != null)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${appState.userName} ${appState.userLastName}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rol: ${appState.userRole}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.deepPurple[700],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
                children: [
                  IconButtonWithText(
                    icon: Icons.account_circle,
                    label: 'Cuenta',
                    onPressed: () {
                      checkAccess('Cuenta', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => GestionUser()),
                        );
                      });
                    },
                  ),
                  IconButtonWithText(
                    icon: Icons.event,
                    label: 'Eventos',
                    onPressed: () {
                      checkAccess('Eventos', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => GestionEvent()),
                        );
                      });
                    },
                  ),
                  IconButtonWithText(
                    icon: Icons.article,
                    label: 'Publicaciones',
                    onPressed: () {
                      checkAccess('Publicaciones', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PublicacionesPage()),
                        );
                      });
                    },
                  ),
                  IconButtonWithText(
                    icon: Icons.analytics,
                    label: 'Reportes',
                    onPressed: () {
                      checkAccess('Reportes', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => GestionReportes()),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            // StreamBuilder lo utilizamos para mostrar publicaciones en tiempo real
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('publications')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No hay publicaciones aún'));
                  }
                  var publicaciones = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: publicaciones.length,
                    itemBuilder: (context, index) {
                      var publicacion = publicaciones[index];
                      return Card(
                        color: Colors.deepPurple[100],
                        margin: EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Imagen grande en la parte superior
                            if (publicacion['imageUrl'] != null &&
                                publicacion['imageUrl'] is String)
                              Container(
                                height: 200, // Tamaño de la imagen más grande
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10)),
                                  image: DecorationImage(
                                    image:
                                        NetworkImage(publicacion['imageUrl']),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    publicacion['titulo'] ?? '',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    publicacion['contenido'] ?? '',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Publicado por: ${publicacion['nombre'] ?? 'Desconocido'}',
                                    style: TextStyle(
                                      color: Colors.black45,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Con esta clase todos los usuarios independientemente de su rol podrán ver las publicaciones creadas por los administradores
class PublicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Método para obtener todas las publicaciones
  Future<List<Map<String, dynamic>>> fetchPublications() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('publications')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Error al obtener publicaciones: $e");
      return [];
    }
  }
}

//En este apartado definimos la página donde se verán todas las opciones de la cuenta, como sus botones para ir a los apartados
class GestionUser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventuallly',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'GESTIÓN DE USUARIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            OptionTile(
              icon: Icons.admin_panel_settings,
              title: 'Administración de roles',
              subtitle: 'Roles y Permisos',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GestionUserRoles()),
                );
              },
            ),
            OptionTile(
              icon: Icons.edit,
              title: 'Edición de cuenta',
              subtitle: 'Datos Personales',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GestionUserEdicion()),
                );
              },
            ),
            OptionTile(
              icon: Icons.delete,
              title: 'Eliminación de cuenta',
              subtitle: 'Dar de Baja',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => GestionUserEliminarCuenta()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

//En esta página podremos ver la pagina donde se podrá modificar el rol del usuario a elección
class GestionUserRoles extends StatefulWidget {
  @override
  GestionUserRolesState createState() => GestionUserRolesState();
}

class GestionUserRolesState extends State<GestionUserRoles> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isAdmin = false;
  bool isOrganizer = false;
  bool isGuest = false;
  bool isRoleSelected = false;
  String? selectedRole;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<MyAppState>(context, listen: false);

    // Cargamos el rol actual del usuario
    if (appState.userRole == 'Admin') {
      isAdmin = true;
    } else if (appState.userRole == 'Organizer') {
      isOrganizer = true;
    } else {
      isGuest = true;
    }
  }

  void updateRole(String role) {
    setState(() {
      selectedRole = role;
      isAdmin = role == "Admin";
      isOrganizer = role == "Organizer";
      isGuest = role == "Participant";
      isRoleSelected = true;
    });
  }

//En este apartado llamamos el metodo que definimos en el MyAppState para el cambio de rol
  Future<void> _updateUserRole() async {
    final appState = Provider.of<MyAppState>(context, listen: false);

    try {
      await appState.updateUserRole(
        emailController.text,
        passwordController.text,
        selectedRole,
      );

      // Mostramos un mensaje de éxito solo si el procesos se cumplió correctamente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rol actualizado exitosamente")),
        );
      }
    } catch (e) {
      // Mostrar mensaje de error solo si el proceso no se cumple
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar el rol: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'EDICIÓN DE ROLES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Correo:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 20),
            Card(
              color: Colors.deepPurple[100],
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Administrador',
                        style: TextStyle(color: Colors.black)),
                    value: isAdmin,
                    onChanged: (bool value) {
                      if (value) updateRole("Admin");
                    },
                  ),
                  SwitchListTile(
                    title: Text('Organizador',
                        style: TextStyle(color: Colors.black)),
                    value: isOrganizer,
                    onChanged: (bool value) {
                      if (value) updateRole("Organizer");
                    },
                  ),
                  SwitchListTile(
                    title: Text('Participante',
                        style: TextStyle(color: Colors.black)),
                    value: isGuest,
                    onChanged: (bool value) {
                      if (value) updateRole("Participant");
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: isRoleSelected ? _updateUserRole : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isRoleSelected ? Colors.deepPurple : Colors.grey,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  'Enviar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//En esta clase definimos todo lo necesario para poder modificar la información del usuario como su nombre y apellido y verse reflejado en tiempo real
class GestionUserEdicion extends StatefulWidget {
  @override
  GestionUserEdicionState createState() => GestionUserEdicionState();
}

class GestionUserEdicionState extends State<GestionUserEdicion> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<MyAppState>(context, listen: false);

    // Cargar los datos actuales del usuario en las casillas donde podremos hacer los cambios
    nameController.text = appState.userName ?? '';
    lastNameController.text = appState.userLastName ?? '';
    emailController.text = appState.user?.email ?? '';
  }

  Future<void> _updateUserData() async {
    final appState = Provider.of<MyAppState>(context, listen: false);

    try {
      // Actualizamos nombre y apellido en la base de datos
      await FirebaseFirestore.instance
          .collection('users')
          .doc(appState.user!.uid)
          .update({
        'nombre': nameController.text,
        'apellido': lastNameController.text,
      });

      // Actualizar la contraseña actual si se ingresa como verificación antes del cambio
      if (newPasswordController.text.isNotEmpty &&
          newPasswordController.text == confirmPasswordController.text) {
        await appState.user!.updatePassword(newPasswordController.text);
      }

      // Actualizamos los datos en el estado de la aplicación como una verificación y se puedan ver en tiempo real
      if (mounted) {
        setState(() {
          appState.userName = nameController.text;
          appState.userLastName = lastNameController.text;
        });
      }

      // Mostrar mensaje de éxito solo si secumple el proceso o error sino se cumple
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Datos actualizados exitosamente")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al actualizar los datos: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'EDICIÓN DE CUENTA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nombre:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: lastNameController,
              decoration: InputDecoration(
                labelText: 'Apellido:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: emailController,
              enabled: false, // Podremos ver el correo mas no editarlo
              decoration: InputDecoration(
                labelText: 'Correo:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña actual:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirmar nueva contraseña:',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  'Guardar cambios',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//En este apartado definimos la eliminación de la cuenta por medio de una confirmación por contraseña
class GestionUserEliminarCuenta extends StatefulWidget {
  @override
  GestionUserEliminarCuentaState createState() =>
      GestionUserEliminarCuentaState();
}

class GestionUserEliminarCuentaState extends State<GestionUserEliminarCuenta> {
  final TextEditingController passwordController = TextEditingController();

  Future<void> _deleteAccount() async {
    var appState = Provider.of<MyAppState>(context, listen: false);

    try {
      await appState.deleteAccount(passwordController.text);

      if (!mounted) return;

      if (!appState.isAuthenticated) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => WelcomePage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error eliminando la cuenta")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error eliminando la cuenta: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'CONFIRMACIÓN DE ELIMINACIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirme su contraseña',
                labelStyle: TextStyle(color: Colors.white),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Eliminar cuenta',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Definimos la página principal para las publicaciones y su conexión con botones para las demás ramas que la componen
class PublicacionesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventuallly',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'GESTIÓN DE PUBLICACIONES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            OptionTile(
              icon: Icons.create,
              title: 'Crear Publicación',
              subtitle: 'Crea y publica información',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CrearPublicacionPage()),
                );
              },
            ),
            OptionTile(
              icon: Icons.edit,
              title: 'Edición de Publicación',
              subtitle: 'Editar información',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditarPublicacionPage()),
                );
              },
            ),
            OptionTile(
              icon: Icons.delete,
              title: 'Eliminación de Publicación',
              subtitle: 'Eliminar información',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EliminarPublicacionPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

//Definición de página para la creación de las publicaciones
class CrearPublicacionPage extends StatefulWidget {
  @override
  CrearPublicacionPageState createState() => CrearPublicacionPageState();
}

class CrearPublicacionPageState extends State<CrearPublicacionPage> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController tituloController = TextEditingController();
  final TextEditingController contenidoController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

  Future<void> _createPublication() async {
    var appState = Provider.of<MyAppState>(context, listen: false);

    try {
      await FirebaseFirestore.instance.collection('publications').add({
        'nombre': nombreController.text,
        'titulo': tituloController.text,
        'contenido': contenidoController.text,
        'imageUrl': imageUrlController
            .text, //Se usará el url de la imagen o gif para la publicación
        'createdAt': FieldValue.serverTimestamp(),
        'userId': appState.user?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Publicación creada exitosamente")),
        );
        Navigator.pop(
            context); //Cuando la publicación se cree se enviará a una página anterior y se verán los cambios en el Homepage
      }
    } catch (e) {
      print("Error al crear la publicación: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al crear la publicación")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'CREACIÓN DE PUBLICACIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del publicante',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: tituloController,
              decoration: InputDecoration(
                labelText: 'Título de Publicación',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: contenidoController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Contenido de Publicación',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: imageUrlController,
              decoration: InputDecoration(
                labelText: 'URL de la imagen',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _createPublication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  'Publicar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//En este apartado configuramos el medio para editar las publicaciones creadas, pudiendo seleccionarla desde un menú desplegable
class EditarPublicacionPage extends StatefulWidget {
  @override
  EditarPublicacionPageState createState() => EditarPublicacionPageState();
}

class EditarPublicacionPageState extends State<EditarPublicacionPage> {
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController tituloController = TextEditingController();
  final TextEditingController contenidoController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

  List<QueryDocumentSnapshot> publicaciones = [];
  QueryDocumentSnapshot? selectedPublicacion;

  @override
  void initState() {
    super.initState();
    fetchPublicaciones();
  }

//En esta función al seleccionar la publicación a editar cargará toda la información que tiene antes del cambio
  Future<void> fetchPublicaciones() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('publications')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      setState(() {
        publicaciones = snapshot.docs;
      });
    }
  }

  void loadPublicacionData(QueryDocumentSnapshot publicacion) {
    nombreController.text = publicacion['nombre'];
    tituloController.text = publicacion['titulo'];
    contenidoController.text = publicacion['contenido'];
    imageUrlController.text = publicacion['imageUrl'];
    setState(() {
      selectedPublicacion = publicacion;
    });
  }

//En esta función configuramos para que la publicaciones se actualicen en tiempo real y salga una notificación
  Future<void> updatePublicacion() async {
    if (selectedPublicacion != null) {
      try {
        await FirebaseFirestore.instance
            .collection('publications')
            .doc(selectedPublicacion!.id)
            .update({
          'nombre': nombreController.text,
          'titulo': tituloController.text,
          'contenido': contenidoController.text,
          'imageUrl': imageUrlController.text,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Publicación actualizada exitosamente")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al actualizar la publicación: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'EDICIÓN DE PUBLICACIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            DropdownButton<QueryDocumentSnapshot>(
              hint: Text(
                "Selecciona una publicación",
                style: TextStyle(color: Colors.white),
              ),
              dropdownColor: Colors.grey[
                  850], //Acá se configura el menú desplegable que lláma toda la información de la publicación
              value: selectedPublicacion,
              items: publicaciones.map((publicacion) {
                return DropdownMenuItem(
                  value: publicacion,
                  child: Text(
                    publicacion['titulo'],
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  loadPublicacionData(value);
                }
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre del publicante',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: tituloController,
              decoration: InputDecoration(
                labelText: 'Título de Publicación',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: contenidoController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Contenido de Publicación',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            TextField(
              controller: imageUrlController,
              decoration: InputDecoration(
                labelText: 'URL de la Imagen',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: updatePublicacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  'Guardar Cambios',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Definimos las página para la eliminación de la publicación a elección del administrador por medio de un menú desplegable como la edición de publicaciones
class EliminarPublicacionPage extends StatefulWidget {
  @override
  EliminarPublicacionPageState createState() => EliminarPublicacionPageState();
}

class EliminarPublicacionPageState extends State<EliminarPublicacionPage> {
  List<QueryDocumentSnapshot> publicaciones = [];
  QueryDocumentSnapshot? selectedPublicacion;

  @override
  void initState() {
    super.initState();
    fetchPublicaciones();
  }

  Future<void> fetchPublicaciones() async {
    //Llamamos toda la información de la publicación a la base de datos
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('publications')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      setState(() {
        publicaciones = snapshot.docs;
      });
    }
  }

//En esta función hacemos que se elimine la publicación seleccionada de la base de datos
  Future<void> deletePublicacion() async {
    if (selectedPublicacion != null) {
      try {
        await FirebaseFirestore.instance
            .collection('publications')
            .doc(selectedPublicacion!.id)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Publicación eliminada exitosamente")),
          );

          setState(() {
            publicaciones.remove(selectedPublicacion);
            selectedPublicacion = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al eliminar la publicación: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventuallly',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ELIMINACIÓN DE PUBLICACIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            DropdownButton<QueryDocumentSnapshot>(
              hint: Text(
                "Selecciona una publicación",
                style: TextStyle(color: Colors.white),
              ),
              dropdownColor: Colors.grey[850],
              value: selectedPublicacion,
              items: publicaciones.map((publicacion) {
                return DropdownMenuItem(
                  value: publicacion,
                  child: Text(
                    publicacion['titulo'],
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedPublicacion = value;
                });
              },
            ),
            SizedBox(height: 20),
            Text(
              '¿Está seguro que desea eliminar la publicación?',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed:
                      selectedPublicacion != null ? deletePublicacion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: Text('Sí', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: Text('No', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//Definimos la página donde se verán todas la opciones de los eventos
class GestionEvent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<MyAppState>(context);
//En esta función damos restricción a los participantes para ver los apartdos de creación y edición de eventos
    void checkAccess(String feature, Function allowedAction) {
      if (appState.userRole == 'Participant' && feature != 'Inscripciones') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No tienes acceso a $feature debido a tu rol.'),
          ),
        );
      } else {
        allowedAction();
      }
    }

//Solo el participante acceder al apartado de inscripciones done podrá ver todos los eventos creados y el organizador la página de los eventos creados por el
//Al igual que los participantes que están inscritos
    void navigateToEventPage(BuildContext context) {
      if (appState.userRole == 'Participant') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ParticipantEventsPage(), //Página para participantes
          ),
        );
      } else if (appState.userRole == 'Organizer') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrganizadorPage(), //Página para organizadores
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'GESTIÓN DE EVENTOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            OptionTile(
              icon: Icons.create,
              title: 'Crear Evento',
              subtitle: 'Crea un nuevo evento',
              onPressed: () {
                checkAccess('Crear Evento', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => GestionEventCreacion()),
                  );
                });
              },
            ),
            OptionTile(
              icon: Icons.edit,
              title: 'Edición de Evento',
              subtitle: 'Editar información',
              onPressed: () {
                checkAccess('Edición de Evento', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => GestionEventEdicion()),
                  );
                });
              },
            ),
            OptionTile(
              icon: Icons.event_available,
              title: 'Inscripción a Eventos',
              subtitle: 'Inscribirse o gestionar inscripciones',
              onPressed: () {
                navigateToEventPage(
                    context); //Esto nos permite una navegación lógica dependiendo del rol del usuario
              },
            ),
          ],
        ),
      ),
    );
  }
}

//Esta es la página para crear eventos sus respectivas caracteristicas
class GestionEventCreacion extends StatefulWidget {
  @override
  GestionEventCreacionState createState() => GestionEventCreacionState();
}

class GestionEventCreacionState extends State<GestionEventCreacion> {
  final TextEditingController tipoController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController autorController = TextEditingController();
//Definimos los controladores para que pueda recibir datos con texto
  DateTime?
      selectedDateTime; //Con este atributo podremos recibir la fecha más la hora de inicio del evento
  List<String> eventTypes = [
    "Musica",
    "Comida",
    "Teatro",
    "Deporte"
  ]; //Esta será una lista de parametros para la categoría del evento
  String? selectedEventType;
  bool isLocationTextFieldVisible = false;
//Definimos las función de creación de evento al igual que al ser creado en la base de datos se tendrá el ID del creador del evento
  Future<void> _createEvent() async {
    var appState = Provider.of<MyAppState>(context, listen: false);
    try {
      await FirebaseFirestore.instance.collection('events').add({
        'tipo': selectedEventType,
        'ubicacion': ubicacionController.text,
        'descripcion': descripcionController.text,
        'fechaHora': selectedDateTime != null
            ? Timestamp.fromDate(selectedDateTime!)
            : null,
        'createdAt': FieldValue.serverTimestamp(),
        'autorUID': appState.user?.uid,
        'autorNombre': autorController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Evento creado exitosamente")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al crear el evento: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isLocationTextFieldVisible) {
          setState(() {
            isLocationTextFieldVisible = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.deepPurple,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'eventually',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'CREACIÓN DE EVENTO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: autorController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Autor',
                  labelStyle: TextStyle(color: Colors.deepPurple[200]),
                  filled: true,
                  fillColor: Colors.grey[850],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              OptionTile(
                icon: Icons.music_note,
                title: 'Tipo de Evento',
                subtitle: selectedEventType ?? 'Selecciona un tipo',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Seleccione el tipo de evento"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: eventTypes.map((type) {
                            return ListTile(
                              title: Text(type),
                              onTap: () {
                                setState(() {
                                  selectedEventType = type;
                                });
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
              OptionTile(
                icon: Icons.calendar_today,
                title: 'Fecha y Hora de Evento',
                subtitle: selectedDateTime != null
                    ? "${selectedDateTime!.toLocal().toString().split(' ')[0]} - ${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}"
                    : 'Selecciona una fecha y hora',
                onPressed: selectDateTime,
              ),
              if (!isLocationTextFieldVisible)
                OptionTile(
                  icon: Icons.location_on,
                  title: 'Ubicación de Evento',
                  subtitle: 'Sitio',
                  onPressed: () {
                    setState(() {
                      isLocationTextFieldVisible = true;
                    });
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: TextField(
                    controller: ubicacionController,
                    decoration: InputDecoration(
                      labelText: 'Ubicación de Evento',
                      labelStyle: TextStyle(color: Colors.deepPurple[200]),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              SizedBox(height: 10),
              TextField(
                controller: descripcionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción del Evento',
                  labelStyle: TextStyle(color: Colors.deepPurple[200]),
                  filled: true,
                  fillColor: Colors.grey[850],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: Text(
                    'Crear Evento',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

//Con esta función podremos seleccionar fecha y hora con un menú adecuado de forma asincrona
  Future<void> selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }
}

//En esta página definimos todo lo necesario para editar el evento al igual que las publicaaciones por medio de un menú para seleccionar el evento a editar
class GestionEventEdicion extends StatefulWidget {
  @override
  GestionEventEdicionState createState() => GestionEventEdicionState();
}

class GestionEventEdicionState extends State<GestionEventEdicion> {
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController autorController = TextEditingController();

  DateTime? selectedDateTime;
  List<String> eventTypes = ["Musica", "Comida", "Teatro", "Deporte"];
  String? selectedEventType;

  List<QueryDocumentSnapshot> eventos = [];
  QueryDocumentSnapshot? selectedEvento;

  bool isLocationTextFieldVisible = false;

  @override
  void initState() {
    super.initState();
    fetchEventos();
  }

  Future<void> fetchEventos() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('events')
        .orderBy('createdAt', descending: true)
        .get();

    if (mounted) {
      setState(() {
        eventos = snapshot.docs;
      });
    }
  }

  void loadEventData(QueryDocumentSnapshot evento) {
    setState(() {
      selectedEvento = evento;
      selectedEventType = evento['tipo'];
      ubicacionController.text = evento['ubicacion'] ?? '';
      descripcionController.text = evento['descripcion'] ?? '';
      autorController.text = evento['autorNombre'] ?? '';
      selectedDateTime = (evento['fechaHora'] as Timestamp).toDate();
    });
  }

//En esta función definimos todo lo necesario para editar el evento y ver los cambios en tiempo real
  Future<void> updateEvent() async {
    if (selectedEvento != null) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(selectedEvento!.id)
            .update({
          'tipo': selectedEventType,
          'ubicacion': ubicacionController.text,
          'descripcion': descripcionController.text,
          'fechaHora': selectedDateTime,
          'autorNombre': autorController.text,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Evento actualizado exitosamente")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al actualizar el evento: $e")),
          );
        }
      }
    }
  }

  void showEventSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: Colors.grey[900],
          child: ListView.builder(
            itemCount: eventos.length,
            itemBuilder: (context, index) {
              var evento = eventos[index];
              return ListTile(
                title: Text(
                  evento['tipo'],
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  loadEventData(evento);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'EDICIÓN DE EVENTO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => showEventSelectionModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                selectedEvento == null
                    ? 'Selecciona un evento'
                    : selectedEvento!['tipo'],
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: autorController,
              decoration: InputDecoration(
                labelText: 'Nombre del Autor',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 10),
            OptionTile(
              icon: Icons.music_note,
              title: 'Tipo de Evento',
              subtitle: selectedEventType ?? 'Selecciona un tipo',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Seleccione el tipo de evento"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: eventTypes.map((type) {
                          return ListTile(
                            title: Text(type),
                            onTap: () {
                              setState(() {
                                selectedEventType = type;
                              });
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
            OptionTile(
              icon: Icons.calendar_today,
              title: 'Fecha y Hora de Evento',
              subtitle: selectedDateTime != null
                  ? "${selectedDateTime!.toLocal().toString().split(' ')[0]} - ${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}"
                  : 'Selecciona una fecha y hora',
              onPressed: selectDateTime,
            ),
            if (!isLocationTextFieldVisible)
              OptionTile(
                icon: Icons.location_on,
                title: 'Ubicación de Evento',
                subtitle: 'Sitio',
                onPressed: () {
                  setState(() {
                    isLocationTextFieldVisible = true;
                  });
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: ubicacionController,
                  decoration: InputDecoration(
                    labelText: 'Ubicación de Evento',
                    labelStyle: TextStyle(color: Colors.deepPurple[200]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            SizedBox(height: 10),
            TextField(
              controller: descripcionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción del Evento',
                labelStyle: TextStyle(color: Colors.deepPurple[200]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: updateEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: Text(
                  'Guardar Cambios',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> selectDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }
}

//En esta pagina definimos los usuarios participantes que estan uniendose a un evento y solo los organizadores podrán verlo
class ParticipantsListPage extends StatelessWidget {
  final String eventoId;

  ParticipantsListPage({required this.eventoId});

  Future<List<QueryDocumentSnapshot>> fetchParticipants() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('inscriptions')
        .where('eventoId', isEqualTo: eventoId)
        .where('role', isEqualTo: 'Participant')
        .get();
    return snapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        //Acá configuramos la lista de los usuarios participantes que iran viendo en la página
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: fetchParticipants(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return ListView(
                children: snapshot.data!.map((participant) {
                  final data = participant.data() as Map<String, dynamic>?;
                  String email = data != null && data.containsKey('email')
                      ? data['email']
                      : 'Email no disponible';
                  String nombre = data?['nombre'] ?? 'Nombre no disponible';

                  return Card(
                    color: Colors.deepPurple.shade100,
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        nombre,
                        style: TextStyle(
                            color: Colors.deepPurple.shade900,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        email,
                        style: TextStyle(color: Colors.deepPurple.shade700),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  );
                }).toList(),
              );
            } else {
              return Center(
                child: Text(
                  "No hay participantes inscritos",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

//Dependiendo del rol si es organizador mostrará esta página al darle a inscripciones de evento
class OrganizadorPage extends StatefulWidget {
  @override
  OrganizadorPageState createState() => OrganizadorPageState();
}

class OrganizadorPageState extends State<OrganizadorPage> {
  List<QueryDocumentSnapshot> eventosOrganizador = [];

  @override
  void initState() {
    super.initState();
    fetchOrganizerEventos();
  }

  Future<void> fetchOrganizerEventos() async {
    var appState = Provider.of<MyAppState>(context, listen: false);
    String? uid = appState.user?.uid;

    // Verificación del UID
    if (uid == null) {
      print("Error: UID del usuario es nulo");
      return;
    }

    try {
      //Con este comando consultamos los eventos creados por el organizador especifico en la base de datos
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('autorUID', isEqualTo: uid)
          .get();

      //Se actualizará en tiempo real si el organizador crea un evento nuevo
      setState(() {
        eventosOrganizador = snapshot.docs;
      });

      //Se mosotrarán los eventos creador por el organizador
      print(
          "Eventos encontrados para el organizador $uid: ${eventosOrganizador.length}");
      for (var doc in eventosOrganizador) {
        print(
            "Evento ID: ${doc.id}, Tipo: ${doc['tipo']}, Descripción: ${doc['descripcion']}");
      }
    } catch (e) {
      print("Error al obtener eventos del organizador: $e");
    }
  }

  void navigateToParticipants(QueryDocumentSnapshot evento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParticipantsListPage(eventoId: evento.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: eventosOrganizador.isEmpty
            ? Center(
                child: Text(
                  "No tienes eventos creados",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              )
            : ListView.builder(
                itemCount: eventosOrganizador.length,
                itemBuilder: (context, index) {
                  var evento = eventosOrganizador[index];
                  return Card(
                    color: Colors.deepPurple.shade100,
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(
                        evento['tipo'],
                        style: TextStyle(
                            color: Colors.deepPurple.shade900,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        evento['descripcion'],
                        style: TextStyle(color: Colors.deepPurple.shade700),
                      ),
                      trailing: Icon(Icons.people, color: Colors.deepPurple),
                      onTap: () => navigateToParticipants(evento),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

//Esta será la página que verá el usuario participante al darle a inscripciones, podrá ver todos los eventos creados en la aplicación
class ParticipantEventsPage extends StatelessWidget {
  Future<List<QueryDocumentSnapshot>> fetchEventos() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('events')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs;
  }

  void showEventDetails(BuildContext context, QueryDocumentSnapshot evento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(eventoId: evento.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text('eventually',
            style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'EVENTOS DISPONIBLES',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: FutureBuilder(
                future: fetchEventos(),
                builder: (context,
                    AsyncSnapshot<List<QueryDocumentSnapshot>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return ListView(
                      children: snapshot.data!.map((evento) {
                        return Card(
                          color: Colors.deepPurple[100],
                          margin: EdgeInsets.symmetric(vertical: 10),
                          child: ListTile(
                            title: Text(evento['tipo'],
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(evento['descripcion'],
                                style: TextStyle(color: Colors.black54)),
                            onTap: () => showEventDetails(context, evento),
                          ),
                        );
                      }).toList(),
                    );
                  } else {
                    return Center(
                        child: Text("No hay eventos disponibles",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//En esta página el participante podrá ver los detalles del evento que el seleccione y la opción de inscribirse o denegar la inscripción
class EventDetailsPage extends StatelessWidget {
  final String eventoId;

  EventDetailsPage({required this.eventoId});

  Future<DocumentSnapshot> fetchEventDetails() async {
    return await FirebaseFirestore.instance
        .collection('events')
        .doc(eventoId)
        .get();
  }

  Future<void> registerForEvent(BuildContext context) async {
    var appState = Provider.of<MyAppState>(context, listen: false);
    String? email = appState.user?.email;

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: el correo electrónico es nulo")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('inscriptions').add({
      'eventoId': eventoId,
      'userId': appState.user?.uid,
      'nombre': appState.userName,
      'email': email,
      'role': 'Participant',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Te has inscrito al evento")),
      );
    }
  }

  Future<void> cancelRegistration(BuildContext context) async {
    var appState = Provider.of<MyAppState>(context, listen: false);
    var inscriptionSnapshot = await FirebaseFirestore.instance
        .collection('inscriptions')
        .where('eventoId', isEqualTo: eventoId)
        .where('userId', isEqualTo: appState.user?.uid)
        .get();

    for (var doc in inscriptionSnapshot.docs) {
      await doc.reference.delete();
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Inscripción cancelada")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          "eventually",
          style: TextStyle(
              fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: fetchEventDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData && snapshot.data!.exists) {
            var event = snapshot.data!;
            var timestamp = event['fechaHora'] as Timestamp?;
            var formattedDate = timestamp != null
                ? DateFormat('dd MMMM yyyy, hh:mm a').format(timestamp.toDate())
                : 'Fecha no disponible';

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'DETALLES DEL EVENTO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text("Tipo: ${event['tipo']}",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 10),
                  Text("Descripción: ${event['descripcion']}",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 10),
                  Text("Ubicación: ${event['ubicacion']}",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 10),
                  Text("Fecha y Hora: $formattedDate",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          minimumSize: Size(130, 40),
                        ),
                        onPressed: () => registerForEvent(context),
                        icon: Icon(Icons.check, color: Colors.white),
                        label: Text(
                          "Inscribirse",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: Size(130, 40),
                        ),
                        onPressed: () => cancelRegistration(context),
                        icon: Icon(Icons.close, color: Colors.white),
                        label: Text(
                          "Cancelar",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Text("No se encontró el evento",
                  style: TextStyle(color: Colors.white)),
            );
          }
        },
      ),
    );
  }
}

//En esta página el usuario organizador podrá ver las opciones que tiene para los reportes
class GestionReportes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Reportes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            OptionTile(
              icon: Icons.assessment,
              title: 'Ver Reportes',
              subtitle: 'Mira tus reportes y editalos!',
              onPressed: () {
                // Navegar a la página MisReportesPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MisReportesPage(),
                  ),
                );
              },
            ),
            OptionTile(
              icon: Icons.add_chart,
              title: 'Generar Reporte',
              subtitle: 'Genera tus reportes',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportOptionsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

//En esta pagina a la hora de darle a generar reportes podrá seleccionar un evento y un tipo de reporte por medio de los menús desplegables
class ReportOptionsPage extends StatefulWidget {
  @override
  ReportOptionsPageState createState() => ReportOptionsPageState();
}

class ReportOptionsPageState extends State<ReportOptionsPage> {
  String? selectedEvent;
  String? selectedReportType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Generar Reporte',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Seleccione un evento creado',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('autorUID',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text(
                    'No hay eventos disponibles.',
                    style: TextStyle(color: Colors.white54),
                  );
                }
                var events = snapshot.data!.docs;
                return DropdownButton<String>(
                  value: selectedEvent,
                  hint: Text(
                    'Seleccione un evento',
                    style: TextStyle(color: Colors.white54),
                  ),
                  items: events.map((event) {
                    return DropdownMenuItem<String>(
                      value: event.id,
                      child: Text(
                        event['descripcion'],
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedEvent = value;
                    });
                  },
                  dropdownColor: Colors.black,
                  style: TextStyle(color: Colors.white),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              'Tipo de reporte',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            DropdownButton<String>(
              value: selectedReportType,
              hint: Text(
                'Seleccione el tipo de reporte',
                style: TextStyle(color: Colors.white54),
              ),
              items: [
                DropdownMenuItem(
                  value: 'Logística y recursos',
                  child: Text('Logística y recursos'),
                ),
                DropdownMenuItem(
                  value: 'Opiniones del organizador',
                  child: Text('Opiniones del organizador'),
                ),
                DropdownMenuItem(
                  value: 'Asistencia',
                  child: Text('Asistencia'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedReportType = value;
                });
              },
              dropdownColor: Colors.black,
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(
                height:
                    20), //Si el organizador elige o logística u opiniones lo enviara la página de reportes de texto
            ElevatedButton(
              onPressed: () {
                if (selectedEvent != null && selectedReportType != null) {
                  if (selectedReportType == 'Logística y recursos' ||
                      selectedReportType == 'Opiniones del organizador') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TextReportPage(
                          eventId: selectedEvent!,
                          reportType: selectedReportType!,
                        ),
                      ),
                    );
                  } else if (selectedReportType == 'Asistencia') {
                    //Si elige el reporte de asistencia lo enviará a la página de reportes de asistencia
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AttendanceReportPage(eventId: selectedEvent!),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Seleccione un evento y un tipo de reporte.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 8,
              ),
              child: Text(
                'Generar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Esta clase optiontile sirve para llamar recursos dinamicos para los menús
class OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Card(
        color: Colors.grey[800],
        child: ListTile(
          leading: Icon(icon, color: Colors.deepPurple),
          title: Text(
            title,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

//Esta será la página para crear los reportes de asistencia
class AttendanceReportPage extends StatelessWidget {
  final String eventId;

  AttendanceReportPage({required this.eventId});

  Future<void> saveAttendanceReport(BuildContext context) async {
    //Primero revisamos si existen participantes en la base de datos
    var attendees = await FirebaseFirestore.instance
        .collection('event_attendees')
        .where('eventId', isEqualTo: eventId)
        .get();

    //Creamos la lista de los participantes inscritos con su nombre y correo
    List<Map<String, dynamic>> attendanceList = attendees.docs.map((doc) {
      return {
        'name': doc['name'] ?? 'Desconocido',
        'email': doc['email'] ?? 'Sin correo',
      };
    }).toList();

    //Guardamos el reporte en la base de datos en la colección de reportes
    await FirebaseFirestore.instance.collection('reportes').add({
      'eventId': eventId,
      'type': 'Asistencia',
      'attendees': attendanceList,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte de asistencia guardado exitosamente.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Generar lista de asistencia',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => saveAttendanceReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 8,
              ),
              child: Text(
                'Guardar Lista de Asistencia',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//El organizador al darle a visualizar los detalles del reporte podrá ver la lista de las asistencias
class VerAsistencias extends StatelessWidget {
  final String eventId;

  VerAsistencias({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inscriptions')
            .where('eventoId', isEqualTo: eventId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No hay asistentes confirmados para este evento.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          var asistentes = snapshot.data!.docs;
          return ListView.builder(
            itemCount: asistentes.length,
            itemBuilder: (context, index) {
              var asistente = asistentes[index];

              return Card(
                color: Colors.grey[800],
                child: ListTile(
                  title: Text(
                    asistente['nombre'] ?? 'Nombre desconocido',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    asistente['email'] ?? 'Sin correo electrónico',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

//Esta será la página para redactar la información del evento si elegimos el reporte de logística u Opiniones
class TextReportPage extends StatelessWidget {
  final String eventId;
  final String reportType;
  final TextEditingController _reportDetailsController =
      TextEditingController();

  TextReportPage({required this.eventId, required this.reportType});

  Future<void> saveTextReport(BuildContext context) async {
    final currentContext =
        context; //Guardamos el reporte de forma local y de forma asincrona

    //Guardamos el reporte en la base de datos
    await FirebaseFirestore.instance.collection('reportes').add({
      'eventId': eventId,
      'type': reportType,
      'details': _reportDetailsController.text,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': FirebaseAuth.instance.currentUser?.uid,
    });
    if (currentContext.mounted) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Reporte guardado exitosamente.')),
      );
      Navigator.pop(currentContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escribe los detalles del reporte:',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            TextField(
              controller: _reportDetailsController,
              maxLines: 8,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Escribe aquí...',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => saveTextReport(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 8,
              ),
              child: Text(
                'Guardar Reporte',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//En esta página el organizador podrá ver sus reportes creados
class MisReportesPage extends StatelessWidget {
  Future<String> getUserName(String userId) async {
//Obtener el nombre del autor del evento
    DocumentSnapshot userSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userSnapshot['name'] ?? 'Desconocido';
  }

  Future<List<String>> getEventDetails(String eventId) async {
    //Obtenermos la información del evento de la base de datos
    DocumentSnapshot eventSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .get();
    return [
      eventSnapshot['tipo'] ?? 'Tipo desconocido', // Tipo del evento
      eventSnapshot['autorNombre'] ?? 'Autor desconocido' // Nombre del autor
    ];
  }

//En toda la estructura posterior se configura el diseño de como se verán los reportes en su página correspondiente
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reportes')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No tienes reportes generados.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          var reportes = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              var reporte = reportes[index];

              return FutureBuilder<List<String>>(
                future: getEventDetails(reporte['eventId'] ?? ''),
                builder: (context, asyncSnapshot) {
                  if (asyncSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return ListTile(
                      title: Text(
                        reporte['type'] ?? 'Tipo desconocido',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text('Cargando detalles...'),
                    );
                  }

                  String eventType = asyncSnapshot.data![0];
                  String authorName = asyncSnapshot.data![1];

                  return Card(
                    color: Colors.grey[800],
                    child: ListTile(
                      title: Text(
                        reporte['type'] ?? 'Tipo desconocido',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de Evento: $eventType',
                            style: TextStyle(color: Colors.white70),
                          ),
                          if ((reporte.data() as Map<String, dynamic>)
                              .containsKey('details'))
                            Text(
                              'Detalles: ${reporte['details']}',
                              style: TextStyle(color: Colors.white70),
                            ),
                          Text(
                            'Fecha: ${reporte['createdAt']?.toDate() ?? 'Sin fecha'}',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Autor: $authorName',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (reporte['type'] == 'Asistencia')
                            IconButton(
                              icon: Icon(Icons.visibility, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VerAsistencias(
                                      eventId: reporte['eventId'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (reporte['type'] != 'Asistencia')
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.yellow),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditarReportePage(
                                        reporteId: reporte.id),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

//Esta será la página para editar los reportes de Logística y Opiniones, solo el texto del reporte
class EditarReportePage extends StatefulWidget {
  final String reporteId;

  EditarReportePage({required this.reporteId});

  @override
  EditarReportePageState createState() => EditarReportePageState();
}

class EditarReportePageState extends State<EditarReportePage> {
  final TextEditingController _controlador = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

//Cargamos la información que tiene el reporte antes del cámbio
  Future<void> _loadReportData() async {
    try {
      DocumentSnapshot reporte = await FirebaseFirestore.instance
          .collection('reportes')
          .doc(widget.reporteId)
          .get();

      if (mounted && reporte.exists) {
        _controlador.text = reporte['details'] ?? '';
      }
    } catch (e) {
      print("Error al cargar el reporte: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

//Esta función se encargará de actualizar en tiempo real el reporte
  Future<void> _actualizarReporte() async {
    await FirebaseFirestore.instance
        .collection('reportes')
        .doc(widget.reporteId)
        .update({'details': _controlador.text});
  }

  void _guardarCambios() async {
    await _actualizarReporte();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reporte actualizado exitosamente.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: Text(
          'eventually',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextField(
                    controller: _controlador,
                    maxLines: 8,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Escribe los detalles del reporte...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _guardarCambios,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding:
                          EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 8,
                    ),
                    child: Text('Guardar Cambios',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }
}

//En esta clase de nuevo llamamos recursos para el diseño de los menús
class IconButtonWithText extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  IconButtonWithText({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(icon, size: 50, color: Colors.deepPurple),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }
}

//Acá definimos la página de login tomando en cuenta el correo y contraseña del usuario al registrarse
class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _loginUser() async {
    var appState = Provider.of<MyAppState>(context, listen: false);

    try {
      //Generamos el intento del login con los campos necesarios registrados
      await appState.login(
        emailController.text,
        passwordController.text,
      );

      if (!mounted) return;

      if (appState.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error en el inicio de sesión")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error en el inicio de sesión: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                color: Colors.deepPurple,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Spacer(),
                    Text(
                      'eventuallly',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'INICIO DE SESIÓN',
                style: TextStyle(
                  color: Colors.deepPurple[200],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email', style: TextStyle(color: Colors.white)),
                    SizedBox(height: 5),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'Correo@email.com',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text('Contraseña', style: TextStyle(color: Colors.white)),
                    SizedBox(height: 5),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Contraseña',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      onPressed: _loginUser,
                      child: Text('Ingresar'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => RegisterPage()),
                        );
                      },
                      child: Text(
                        'No tienes cuenta? Regístrate',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Definimos la página de registro con los datos necesarios más la selección del rol
class RegisterPage extends StatefulWidget {
  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController apellidoController = TextEditingController();
  String? selectedRole;

  bool isAdmin = false;
  bool isOrganizer = false;
  bool isParticipant = false;

  void updateRole(String role) {
    setState(() {
      selectedRole = role;
      isAdmin = role == "Admin";
      isOrganizer = role == "Organizer";
      isParticipant = role == "Participant";
    });
  }

  Future<void> _registerUser() async {
    if (!mounted) {
      return; // El registro de usuario es un metodo asincrono
    }

    final appState = Provider.of<MyAppState>(context, listen: false);

    //Se guarda la información del usuario en la base de datos
    final registrationSuccess = await appState.register(
      emailController.text,
      passwordController.text,
      nombreController.text,
      apellidoController.text,
      selectedRole!,
    );

    if (!mounted) {
      return;
    }

    if (registrationSuccess) {
      if (mounted) {
        // Mostrar SnackBar de éxito antes de la navegación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registro exitoso")),
        );

        // Redirigir al WelcomePage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) =>
                  WelcomePage()), //Al registrarse lo enviara a la página de bienvenida para iniciar sesión
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error en el registro")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                color: Colors.deepPurple,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Spacer(),
                    Text(
                      'eventually',
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(
                'REGISTRO',
                style: TextStyle(
                  color: Colors.deepPurple[200],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: InputDecoration(labelText: 'Nombre'),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: apellidoController,
                      decoration: InputDecoration(labelText: 'Apellido'),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: 'Correo'),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: 'Contraseña'),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Selecciona un rol:',
                      style: TextStyle(color: Colors.white),
                    ),
                    SwitchListTile(
                      title: Text("Administrador",
                          style: TextStyle(color: Colors.black)),
                      value: isAdmin,
                      onChanged: (bool value) {
                        if (value) updateRole("Admin");
                      },
                    ),
                    SwitchListTile(
                      title: Text("Organizador",
                          style: TextStyle(color: Colors.black)),
                      value: isOrganizer,
                      onChanged: (bool value) {
                        if (value) updateRole("Organizer");
                      },
                    ),
                    SwitchListTile(
                      title: Text("Participante",
                          style: TextStyle(color: Colors.black)),
                      value: isParticipant,
                      onChanged: (bool value) {
                        if (value) updateRole("Participant");
                      },
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _registerUser,
                      child: Text('Registrarse'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
