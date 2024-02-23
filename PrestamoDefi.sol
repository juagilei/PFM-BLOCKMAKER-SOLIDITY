// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PrestamoDefi {

// Declaración de variables globales.

    address public socioPrincipal;

// Dtos del Prestamo.

    struct Prestamo {
        uint256 id;
        address prestatario;
        uint256 monto;
        uint256 plazo;
        uint256 tiempoSolicitud;
        uint256 tiempoLimite;
        bool aprobado;
        bool reembolsado;
        bool liquidado;
    }

// Datos del cliente y relación con el prestamo.

    struct Cliente {
        bool activado;
        uint256 saldoGarantia;
        mapping(uint256 => Prestamo) prestamos;
        uint256[] prestamoIds;
    }

// Mapeos para encontrar datos de los clientes y prestamistas.

    mapping(address => Cliente) public clientes;
    mapping(address => bool) public empleadosPrestamista;

// Eventos para emitir información.

    event SolicitudPrestamo (address indexed prestatario, uint256 monto, uint256 plazo);
    event PrestamoAprobado (address indexed  prestatario, uint256 monto);
    event PrestamoReembolsado (address indexed prestatario, uint256 monto);
    event GarantiaLiquidada (address indexed  prestatario, uint256 monto);

// Modificadores para restringir accesos a funciones.

    modifier soloSocioPrincipal () {
        require(msg.sender == socioPrincipal, "Error, no pudes realizar esta accion por que no eres el socio proncipal");
        _;
    }
    modifier soloSocioEmpleadoPrestamista () {
        require( empleadosPrestamista[msg.sender] == true, "Error, no estas dado de alta" );
        _;
    }
    modifier soloClienteRegistrado (){
        require( clientes[msg.sender].activado == true, "Error, el cliente no esta registrado");
        _;
    }

// El socio principal se inicia como primier prestamista.

    constructor (){
        socioPrincipal = msg.sender;
        empleadosPrestamista[socioPrincipal] = true;
    }

// Función donde el socio principal da de alta a un nuevo prestamista siempre que no este dado ya de alta.

    function altaPrestamista (address nuevoPrestamista_) public soloSocioPrincipal{
        require ( !empleadosPrestamista [nuevoPrestamista_], "Error el pretamista ya esta dado de alta");

        empleadosPrestamista [nuevoPrestamista_] = true;

    }

// Función que se encarga de añadir un nuevo cliente.

    function altaCliente(address nuevoCliente_) public soloSocioEmpleadoPrestamista{
        require (!clientes[nuevoCliente_].activado, "Error, el cliente ya estaba dado de alta");

    // creamos instancia tipo storage para usar el struct entero sin ir añadiendo partes.

       Cliente storage structNuevoCliente = clientes[nuevoCliente_];
        structNuevoCliente.saldoGarantia = 0;
        structNuevoCliente.activado = true;

    }

// Función para depositar la garantía.

    function depositarGarantia()  public payable {

        clientes[msg.sender].saldoGarantia += msg.value;

    }

// Función que permite al cliente solicitar un prestamo.

    function solicitarPrestamos (uint256 monto_, uint256 plazo_) public  soloClienteRegistrado returns(uint256){
        require(clientes[msg.sender].saldoGarantia >= monto_, "Error, no tiene suficiente saldo de garantia");
        uint256 nuevoId = clientes[msg.sender].prestamoIds.length + 1;

        // creamos instancia tipo storage para usar el struct entero sin ir añadiendo partes.
        // se usa storage y no memory por que asi quedan los datos guardados y no se borran.

        Prestamo storage nuevoPrestamo = clientes[msg.sender].prestamos[nuevoId];

        nuevoPrestamo.id = nuevoId;
        nuevoPrestamo.prestatario = msg.sender;
        nuevoPrestamo.monto = monto_;
        nuevoPrestamo.plazo = plazo_;
        nuevoPrestamo.tiempoSolicitud = block.timestamp;
        nuevoPrestamo.tiempoLimite = 0;
        nuevoPrestamo.aprobado = false;
        nuevoPrestamo.reembolsado = false;
        nuevoPrestamo.liquidado = false;

        // Añadimos la nueva instancia al array mediante push.

        clientes[msg.sender].prestamoIds.push(nuevoId);

        // Emitimos el evento y devolvemos el identificador del prestamo.

        emit SolicitudPrestamo (msg.sender, monto_, plazo_);
        return nuevoId;

    }
// Función para aprobar el prestamo.

    function aprobarPrestamo (address prestatario_, uint256 id_) public soloSocioEmpleadoPrestamista{

    // Almacenamos los datos del cliente en una variable para trabajar mas cómodo.

        Cliente storage prestatario = clientes[prestatario_];

    // Comprbamos que el prestamo ha sido solicitado.

        require(id_ > 0 && id_ <= prestatario.prestamoIds.length, "Error, la ID no es valida");
    
    // Almacenamos los datos del prestamos en struct prestamo.

         Prestamo storage prestamo = prestatario.prestamos[id_];

    // Comprobación del prestamo.

        require(!prestamo.aprobado, "Error, el prestamo esta aprobado");
        require(!prestamo.reembolsado, "Error, el prestamo ha sido reembolsado");
        require(!prestamo.liquidado, "Error, el prestamo ha sido liquidado");
    
    // Procedimiento de aprobación del prestamo con el plazo y emision de la aprobación del prestamo.

    prestamo.aprobado = true;
        prestamo.tiempoLimite = block.timestamp + prestamo.plazo;

        emit PrestamoAprobado(prestatario_, prestamo.monto);
    }

// Función que permite al prestatario reembolsar la cantidad pendiente del presatamo.

    function reembolsarPrestamo(uint256 id_) public soloClienteRegistrado{

    // Almacenamos los datos del cliente en una variable para tranajar mas cómodo.

        Cliente storage prestatario = clientes[msg.sender];

        require(id_ > 0 && id_ <= prestatario.prestamoIds.length, "Error, la ID no es valido");

    // Almacenamos los datos del  prestamo en una variable para tranajar mas cómodo.
        
        Prestamo storage prestamo = prestatario.prestamos[id_];

        require(msg.sender == prestamo.prestatario, "Error, no es el prestatario del prestamo");
        require(prestamo.aprobado, "Error, el prestamo no esta aprobado");
        require(!prestamo.reembolsado, "Error, el prestamo esta reembolsado");
        require(!prestamo.liquidado, "Error, el prestamo esta liquidado");
        require(block.timestamp <= prestamo.tiempoLimite, "Error, se ha pasado el tiempo de pago");

        // Reembolso del prestamo.

         payable(socioPrincipal).transfer(prestamo.monto);

        prestamo.reembolsado = true;

        prestatario.saldoGarantia -= prestamo.monto;

          emit PrestamoReembolsado(msg.sender, prestamo.monto);
    }

     

    // Función que nos permite liquidar la cantidad del préstamo pendiente.

        function liquidarGrantia (address prestatario_, uint256 id_) public soloSocioEmpleadoPrestamista{

         // Almacenamos los datos del cliente en una variable para trabajar mas cómodo.

            Cliente storage prestatario = clientes[prestatario_];

        // comprobamos que el prestamo del cliente existe y lo almaceno en una variable.

        require(id_ > 0 && id_ <= prestatario.prestamoIds.length, "Error, la ID no es valido");
        
        Prestamo storage prestamo = prestatario.prestamos[id_];

        // Comprobaciones del prestamos.

        require(prestamo.aprobado, "Error, el prestamo no esta aprobado");
        require(!prestamo.reembolsado, "Error, el prestamo esta reembolsado");
        require(!prestamo.liquidado, "Error, el prestamo esta liquidado");
        require(block.timestamp > prestamo.tiempoLimite, "Error, no se ha pasado el tiempo de pago");

        // liquidación.

        payable(socioPrincipal).transfer(prestamo.monto);

        prestamo.liquidado = true;
        prestatario.saldoGarantia -= prestamo.monto;

        // Emision de la acción.

         emit GarantiaLiquidada(prestatario_, prestamo.monto);

        }
    
    // Función para obtener el listado de los prestamos solicitados por el prestatario.

        function obtenerPrestamosPorPrestatario(address prestatario_) public view returns(uint256[] memory) {

            return (clientes[prestatario_].prestamoIds);

        }
    
    // Función para obtener el detalle del prestamo.

        function obtenerDetallaPrestamo(address prestatario_, uint256 id_ ) public view returns(Prestamo memory) {
            return(clientes[prestatario_].prestamos[id_]);
        }

}    
    
