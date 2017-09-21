+dk dynk
      module dynk

      IMPLICIT NONE

! We have to declare all this stuff, and we can't set them PRIVATE.
! Therefore, we always need to import the DYNK module using "only",
! or else it will bring the contents of parpro, comgetfields,
! and stringzerotrim along with it...

!For nele
+ca parpro

!For the string length stuff
+ca comgetfields
+ca stringzerotrim !Note: Must include this again if linking to stringzerotrim to work.


!+cd   comdynk

!     A.Mereghetti, for the FLUKA Team,
!     K.Sjobak and A. Santamaria, BE-ABP/HSS
!     last modified: 30/10-2014
!     
!     COMMON for dynamic kicks (DYNK)
!     always in main code
!     
!     See TWIKI for documentation
!
!     Needs blocks parpro (for nele) and stringzerotrim (for stringzerotrim_maxlen)
!     and comgetfields (for getfields_l_max_string)


*     general-purpose variables
      logical ldynk            ! dynamic kick requested, i.e. DYNK input bloc issued in the fort.3 file
      logical ldynkdebug       ! print debug messages in main output
      logical ldynkfiledisable ! Disable writing dynksets.dat?

C     Store the FUN statements
      integer maxfuncs_dynk, maxdata_dynk, maxstrlen_dynk
      parameter (maxfuncs_dynk=100,maxdata_dynk=50000,
     &     maxstrlen_dynk=stringzerotrim_maxlen)

      integer funcs_dynk (maxfuncs_dynk,5) ! 1 row/FUN, cols are: 
                                           ! (1) = function name in fort.3 (points within cexpr_dynk),
                                           ! (2) = indicates function type
                                           ! (3,4,5) = arguments (often pointing within other arrays {i|f|c}expr_dynk)
      ! Data for DYNK FUNs
      integer,                  allocatable :: iexpr_dynk (:)
      double precision,         allocatable :: fexpr_dynk (:)
      character(maxstrlen_dynk),allocatable :: cexpr_dynk (:)
      
      integer nfuncs_dynk, niexpr_dynk, nfexpr_dynk, ncexpr_dynk !Number of used positions in arrays
            
C     Store the SET statements
      integer maxsets_dynk
      parameter (maxsets_dynk=200)
      integer sets_dynk(maxsets_dynk, 4) ! 1 row/SET, cols are:
                                         ! (1) = function index (points within funcs_dynk)
                                         ! (2) = first turn num. where it is active
                                         ! (3) =  last turn num. where it is active
                                         ! (4) = Turn shift - number added to turn before evaluating the FUN
      character(maxstrlen_dynk) csets_dynk (maxsets_dynk,2) ! 1 row/SET (same ordering as sets_dynk), cols are:
                                                            ! (1) element name
                                                            ! (2) attribute name

      integer nsets_dynk ! Number of used positions in arrays
      
      character(maxstrlen_dynk) csets_unique_dynk (maxsets_dynk,2) !Similar to csets_dynk,
                                                                   ! but only one entry per elem/attr
      double precision fsets_origvalue_dynk(maxsets_dynk) ! Store original value from dynk
      integer nsets_unique_dynk ! Number of used positions in arrays

      ! Some elements (multipoles) overwrites the general settings info when initialized.
      ! Store this information on the side.
      ! Also used by setvalue and getvalue
      integer dynk_izuIndex
      dimension dynk_izuIndex(nele)
      double precision dynk_elemdata(nele,3)
      
!     fortran COMMON declaration follows padding requirements
c$$$      common /dynkComGen/ ldynk, ldynkdebug, ldynkfiledisable
c$$$
c$$$      common /dynkComExpr/ funcs_dynk,
c$$$     &     iexpr_dynk, fexpr_dynk, cexpr_dynk,
c$$$     &     nfuncs_dynk, niexpr_dynk, nfexpr_dynk, ncexpr_dynk
c$$$
c$$$      common /dynkComSet/ sets_dynk, csets_dynk, nsets_dynk
c$$$      common /dynkComUniqueSet/
c$$$     &     csets_unique_dynk, fsets_origvalue_dynk, nsets_unique_dynk
c$$$     
c$$$      common /dynkComReinitialize/ dynk_izuIndex, dynk_elemdata

+if cr
!+cd comdynkcr
C     Block with data/fields needed for checkpoint/restart of DYNK
      ! Number of records written to dynkfile (dynksets.dat)
      integer dynkfilepos, dynkfilepos_cr
      
      ! Data for DYNK FUNs
      integer,                  allocatable :: iexpr_dynk_cr (:)
      double precision,         allocatable :: fexpr_dynk_cr (:)
      character(maxstrlen_dynk),allocatable :: cexpr_dynk_cr (:)
      ! Number of used positions in arrays
      integer niexpr_dynk_cr, nfexpr_dynk_cr, ncexpr_dynk_cr
      
      ! Store current settings from dynk
      double precision fsets_dynk_cr(maxsets_dynk)

c$$$      common /dynkComCR/ dynkfilepos,dynkfilepos_cr
c$$$      common /dynkComExprCR/
c$$$     &     iexpr_dynk_cr, fexpr_dynk_cr, cexpr_dynk_cr,
c$$$     &     niexpr_dynk_cr, nfexpr_dynk_cr, ncexpr_dynk_cr
c$$$      
c$$$      common /dynkComUniqueSetCR/
c$$$     &     fsets_dynk_cr
+ei
      
!
!-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
!
      save ldynk, ldynkdebug, ldynkfiledisable
      save funcs_dynk,
     &     iexpr_dynk, fexpr_dynk, cexpr_dynk,
     &     nfuncs_dynk, niexpr_dynk, nfexpr_dynk, ncexpr_dynk
      save sets_dynk, csets_dynk, nsets_dynk
      save csets_unique_dynk, fsets_origvalue_dynk, nsets_unique_dynk
      save dynk_izuIndex, dynk_elemdata
+if cr
      save dynkfilepos,dynkfilepos_cr
      save iexpr_dynk_cr, fexpr_dynk_cr, cexpr_dynk_cr,
     &     niexpr_dynk_cr, nfexpr_dynk_cr, ncexpr_dynk_cr
      save fsets_dynk_cr
+ei
      
      contains                  !HERE COMES THE SUBROUTINES!

      subroutine dynk_allocate
      implicit none

+ca crcoall

+ca parnum

      integer stat
      integer i,j
      
      write(lout,'(A,I8)') "DYNK_ALLOCATE : maxdata_dynk=",
     &     maxdata_dynk
      allocate( iexpr_dynk(maxdata_dynk),
     &          fexpr_dynk(maxdata_dynk),
     &          cexpr_dynk(maxdata_dynk),
     &     STAT=stat)
      
      if (stat.ne.0) then
         write(lout,'(A,I8)') "ERROR in DYNK_ALLOCATE; stat=",stat
         call prror(-1)
      endif
      
! Zero the memory, as is done in comnul.
! One disadvantage of doing this is that we force all the memory to be real,
! while in most cases much of it could actually be virtual...
      do i=1,maxdata_dynk
         iexpr_dynk(i) = 0
         fexpr_dynk(i) = zero
         do j=1,maxstrlen_dynk
            cexpr_dynk(i)(j:j) = char(0)
         enddo
      enddo

+if cr
      write(lout,'(A,I8)') "DYNK_ALLOCATE [CR] : maxdata_dynk=",
     &     maxdata_dynk
      allocate( iexpr_dynk_cr(maxdata_dynk),
     &          fexpr_dynk_cr(maxdata_dynk),
     &          cexpr_dynk_cr(maxdata_dynk),
     &     STAT=stat)
      
      if (stat.ne.0) then
         write(lout,'(A,I8)') "ERROR in DYNK_ALLOCATE [CR]; stat=",stat
         call prror(-1)
      endif
+ei
      
      end subroutine
      
      
      subroutine dynk_parseFUN( getfields_fields,
     &                          getfields_lfields,getfields_nfields )
!
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 30-10-2014
!     parse FUN lines in the fort.3 input file, 
!     store it in COMMON block dynkComExpr.
!-----------------------------------------------------------------------
!     
      implicit none
+ca comgetfields
+ca stringzerotrim
+ca crcoall

      intent(in) getfields_fields, getfields_lfields, getfields_nfields
      
      ! Temp variables
      integer ii, stat, t
      double precision x,y,z,u,           ! FILE, FILELIN, FIR/IIR
     &                 x1,x2,y1,y2,deriv, ! LINSEG, QUADSEG,
     &                 tinj,Iinj,Inom,A,D,R,te,                 !PELP (input)
     &                 derivI_te,I_te,bexp,aexp, t1,I1, td,tnom !PELP (calc)
      
      logical isFIR ! FIR/IIR
      
      logical lopen

+if crlibm
      integer nchars
      parameter (nchars=160) !Same as in daten
      character*(nchars) ch
      
      character filefields_fields
     &     ( getfields_n_max_fields )*( getfields_l_max_string )
      integer filefields_nfields
      integer filefields_lfields( getfields_n_max_fields )
      logical filefields_lerr
      
      double precision round_near
      integer errno
+ei

+if boinc
      character*256 filename
+ei

+if fio
! Do not support FIO, it is not supported by any compilers.
      write (lout,*) "FIO not supported in DYNK!"
      call prror(-1)
+ei
      
      if (nfuncs_dynk+1 .gt. maxfuncs_dynk) then
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "Maximum number of FUN exceeded, please" //
     &        "parameter maxfuncs_dynk."
         write (lout,*) "Current value of maxfuncs_dynk:",maxfuncs_dynk
         call prror(51)
      endif

      if (getfields_lfields(2).gt.maxstrlen_dynk-1 .or.
     &    getfields_lfields(2).gt.20                    ) then
         write(lout,*) "ERROR in DYNK block parsing (fort.3):"
         write(lout,*) "Max length of a FUN name is the smallest of",
     &        maxstrlen_dynk-1, "and", 20, "."
         write(lout,*) "The limitation of 20 comes from the output "//
     &        "to dynksets.dat."
         write(lout,*) "Offending FUN: '"//
     &        getfields_fields(2)(1:getfields_lfields(2))//"'"
         write(lout,*) "length:", getfields_lfields(2)
         call prror(51)
      endif
      
      ! ! ! ! ! ! ! ! ! ! ! ! ! !
      ! Which type of function? !
      ! ! ! ! ! ! ! ! ! ! ! ! ! !

      !!! System functions: #0-19 !!!
      select case ( getfields_fields(3)(1:getfields_lfields(3)) )
      case ("GET")
         ! GET: Store the value of an element/value

         call dynk_checkargs(getfields_nfields,5,
     &        "FUN funname GET elementName attribute" )
         call dynk_checkspace(0,1,3)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 0           !TYPE (GET)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3

         !Sanity checks
         if (getfields_lfields(4) .gt. 16 .or.   ! length of BEZ elements
     &       getfields_lfields(4) .gt. maxstrlen_dynk-1 ) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN GET got an element name with     "
            write (lout,*) "length =", getfields_lfields(4), "> 16"
            write (lout,*) "or > ",maxstrlen_dynk-1
            write (lout,*) "The name was: '",getfields_fields(4)
     &                                    (1:getfields_lfields(4)),"'"
            write (lout,*) "*************************************"
            call prror(51)
         end if
         if (getfields_lfields(5) .gt. maxstrlen_dynk-1) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN GET got an attribute name with   "
            write (lout,*) "length =", getfields_lfields(5)
            write (lout,*) "> ",maxstrlen_dynk-1
            write (lout,*) "The name was: '",getfields_fields(5)
     &                                    (1:getfields_lfields(5)),"'"
            write (lout,*) "*************************************"
            call prror(51)
         endif

         ! Store data
         cexpr_dynk(ncexpr_dynk  )(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         cexpr_dynk(ncexpr_dynk+1)(1:getfields_lfields(4)) = !ELEMENT_NAME
     &        getfields_fields(4)(1:getfields_lfields(4))
         cexpr_dynk(ncexpr_dynk+2)(1:getfields_lfields(5)) = !ATTRIBUTE_NAME
     &        getfields_fields(5)(1:getfields_lfields(5))
         ncexpr_dynk = ncexpr_dynk+2
         
         fexpr_dynk(nfexpr_dynk) = -1.0 !Initialize a place in the array to store the value

      case ("FILE")
         ! FILE: Load the contents from a file
         ! File format: two ASCII columns of numbers,
         ! first  column = turn number (all turns should be there, starting from 1)
         ! second column = value (as a double)

         call dynk_checkargs(getfields_nfields,4,
     &        "FUN funname FILE filename" )
         call dynk_checkspace(0,0,2)
         
         ! Set pointers to start of funs data blocks (nfexpr_dynk handled when reading data)
         nfuncs_dynk = nfuncs_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk   !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 1             !TYPE (FILE)
         funcs_dynk(nfuncs_dynk,3) = ncexpr_dynk+1 !Filename (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,4) = nfexpr_dynk+1 !Data     (in fexpr_dynk)
         funcs_dynk(nfuncs_dynk,5) = -1            !Below: Length of file

         !Sanity checks
         if (getfields_lfields(4) .gt. maxstrlen_dynk-1) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN FILE got a filename name with   "
            write (lout,*) "length =", getfields_lfields(4)
            write (lout,*) "> ",maxstrlen_dynk-1
            write (lout,*) "The name was: '",getfields_fields(4)
     &                                    (1:getfields_lfields(4)),"'"
            write (lout,*) "*************************************"
            call prror(51)
         endif

         ! Store data
         cexpr_dynk(ncexpr_dynk  )(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         cexpr_dynk(ncexpr_dynk+1)(1:getfields_lfields(4)) = !FILE NAME
     &        getfields_fields(4)(1:getfields_lfields(4))
         ncexpr_dynk = ncexpr_dynk+1
         
         !Open the file
         inquire( unit=664, opened=lopen )
         if (lopen) then
            write(lout,*)"DYNK> **** ERROR in dynk_parseFUN():FILE ****"
            write(lout,*)"DYNK> unit 664 for file '" //
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) //
     &           "' was already taken"
            call prror(-1)
         end if

+if boinc
         call boincrf(cexpr_dynk(ncexpr_dynk),filename)
         open(unit=664,file=filename,action='read',
     &        iostat=stat,status="OLD")
+ei
+if .not.boinc
         open(unit=664,file=cexpr_dynk(ncexpr_dynk),action='read',
     &        iostat=stat,status="OLD")
+ei
         if (stat .ne. 0) then
            write(lout,*) "DYNK> dynk_parseFUN():FILE"
            write(lout,*) "DYNK> Error opening file '" //
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
            call prror(51)
         endif

         ii = 0 !Number of data lines read
         do
+if .not.crlibm
            read(664,*, iostat=stat) t,y
            if (stat .ne. 0) exit !EOF
+ei
+if crlibm
            read(664,'(a)', iostat=stat) ch
            if (stat .ne. 0) exit !EOF
            call getfields_split(ch,
     &           filefields_fields, filefields_lfields,
     &           filefields_nfields, filefields_lerr )
            if ( filefields_lerr ) then
               write(lout,*) "DYNK> dynk_parseFUN():FILE"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write(lout,*) "DYNK> Error in getfields_split"
               call prror(-1)
            end if

            if ( filefields_nfields  .ne. 2 ) then
               write(lout,*) "DYNK> dynk_parseFUN():FILE"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write(lout,*) "DYNK> expected 2 fields, got",
     &              filefields_nfields, "ch =",ch
               call prror(-1)
            end if

            read(filefields_fields(1)(1:filefields_lfields(1)),*) t
            y = round_near(errno, filefields_lfields(2)+1,
     &           filefields_fields(2) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,2,y)
!            write(*,*) "DBGDBG: ch=",ch
!            write(*,*) "DBGDBG: filefields_fields(1)=",
!     &           filefields_fields(1)
!            write(*,*) "DBGDBG: filefields_fields(2)=",
!     &           filefields_fields(2)
+ei
!            write(*,*) "DBGDBG: t,y = ",t,y

            ii = ii+1
            if (t .ne. ii) then
               write(lout,*) "DYNK> dynk_parseFUN():FILE"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write(lout,*) "DYNK> Missing turn number", ii,
     &              ", got turn", t
               call prror(51)
            endif
            if (nfexpr_dynk+1 .gt. maxdata_dynk) then
               write(lout,*) "DYNK> dynk_parseFUN():FILE"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write(lout,*) "DYNK> Ran out of memory in fexpr_dynk ",
     &              "in turn", t
               write(lout,*) "DYNK> Please increase maxdata_dynk."
               call prror(51)
            endif
            
            nfexpr_dynk = nfexpr_dynk+1
            fexpr_dynk(nfexpr_dynk) = y
         enddo
         funcs_dynk(nfuncs_dynk,5) = ii
         
         close(664)

      case ("FILELIN")
         ! FILELIN: Load the contents from a file, linearly interpolate
         ! File format: two ASCII columns of numbers,
         ! first  column = turn number (as a double)
         ! second column = value (as a double)

         call dynk_checkargs(getfields_nfields,4,
     &        "FUN funname FILELIN filename" )
         call dynk_checkspace(0,0,2)

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk   !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 2             !TYPE (FILELIN)
         funcs_dynk(nfuncs_dynk,3) = ncexpr_dynk+1 !Filename (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,4) = nfexpr_dynk+1 !Data     (in fexpr_dynk)
         funcs_dynk(nfuncs_dynk,5) = -1            !Below: Length of file (number of x,y sets)
         !Sanity checks
         if (getfields_lfields(4) .gt. maxstrlen_dynk-1) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN FILELIN got a filename name with   "
            write (lout,*) "length =", getfields_lfields(4)
            write (lout,*) "> ",maxstrlen_dynk-1
            write (lout,*) "The name was: '",getfields_fields(4)
     &                                    (1:getfields_lfields(4)),"'"
            write (lout,*) "*************************************"
            call prror(51)
         endif
         ! Store data
         cexpr_dynk(ncexpr_dynk  )(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         cexpr_dynk(ncexpr_dynk+1)(1:getfields_lfields(4)) = !FILE NAME
     &        getfields_fields(4)(1:getfields_lfields(4))
         ncexpr_dynk = ncexpr_dynk+1
         
         !Open the file
         inquire( unit=664, opened=lopen )
         if (lopen) then
            write(lout,*)
     &           "DYNK> **** ERROR in dynk_parseFUN():FILELIN ****"
            write(lout,*)"DYNK> unit 664 for file '"//
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) //
     &           "' was already taken"
            call prror(-1)
         end if
+if boinc
         call boincrf(cexpr_dynk(ncexpr_dynk),filename)
         open(unit=664,file=filename,action='read',
     &        iostat=stat,status='OLD')
+ei
+if .not.boinc
         open(unit=664,file=cexpr_dynk(ncexpr_dynk),action='read',
     &        iostat=stat,status='OLD')
+ei
         if (stat .ne. 0) then
            write(lout,*) "DYNK> dynk_parseFUN():FILELIN"
            write(lout,*) "DYNK> Error opening file '" //
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) //  "'"
            call prror(51)
         endif
         ! Find the size of the file
         ii = 0 !Number of data lines read
         do
+if .not.crlibm
            read(664,*, iostat=stat) x,y
            if (stat .ne. 0) exit !EOF
+ei
+if crlibm
            read(664,'(a)', iostat=stat) ch
            if (stat .ne. 0) exit !EOF
            call getfields_split(ch,
     &           filefields_fields, filefields_lfields,
     &           filefields_nfields, filefields_lerr )
            if ( filefields_lerr ) then
               write(lout,*) "DYNK> dynk_parseFUN():FILELIN"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) //"'"
               write(lout,*) "DYNK> Error in getfields_split"
               call prror(-1)
            end if
            
            if ( filefields_nfields  .ne. 2 ) then
               write(lout,*) "DYNK> dynk_parseFUN():FILELIN"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write(lout,*) "DYNK> expected 2 fields, got",
     &              filefields_nfields, "ch =",ch
               call prror(-1)
            end if

            x = round_near(errno, filefields_lfields(1)+1,
     &           filefields_fields(1) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,1,x)
            y = round_near(errno, filefields_lfields(2)+1,
     &           filefields_fields(2) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,2,y)
            
!            write(*,*) "DBGDBG: ch=",ch
!            write(*,*) "DBGDBG: filefields_fields(1)=",
!     &           filefields_fields(1)(1:filefields_lfields(1))
!            write(*,*) "DBGDBG: filefields_fields(2)=",
!     &           filefields_fields(2)(1:filefields_lfields(2))
+ei
!            write(*,*) "DBGDBG: x,y = ",x,y
            
            if (ii.gt.0 .and. x.le. x2) then !Insane: Decreasing x
               write (lout,*) "DYNK> dynk_parseFUN():FILELIN"
               write (lout,*) "DYNK> Error while reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write (lout,*) "DYNK> x values must "//
     &              "be in increasing order"
               call prror(-1)
            endif
            x2 = x
            
            ii = ii+1
         enddo
         t = ii
         rewind(664)
         
         if (nfexpr_dynk+2*t .gt. maxdata_dynk) then
            write (lout,*) "DYNK> dynk_parseFUN():FILELIN"
            write (lout,*) "DYNK> Error reading file '"//
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
            write (lout,*) "DYNK> Not enough space in fexpr_dynk,"//
     &           " need", 2*t
            write (lout,*) "DYNK> Please increase maxdata_dynk"
            call prror(51)
         endif

         !Read the file
         ii = 0
         do
+if .not.crlibm
            read(664,*, iostat=stat) x,y
            if (stat .ne. 0) then !EOF
               if (ii .ne. t) then
                  write (lout,*)"DYNK> dynk_parseFUN():FILELIN"
                  write (lout,*)"DYNK> Unexpected when reading file '"//
     &                trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
                  write (lout,*)"DYNK> ii=",ii,"t=",t
                  call prror(51)
               endif
               exit
            endif
+ei
+if crlibm
            read(664,'(a)', iostat=stat) ch
            if (stat .ne. 0) then !EOF
               if (ii .ne. t) then
                  write (lout,*)"DYNK> dynk_parseFUN():FILELIN"
                  write (lout,*)"DYNK> Unexpected when reading file '"//
     &                trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
                  write (lout,*) "DYNK> ii=",ii,"t=",t
                  call prror(51)
               endif
               exit
            endif
            
            call getfields_split(ch,
     &           filefields_fields, filefields_lfields,
     &           filefields_nfields, filefields_lerr )
            if ( filefields_lerr ) then
               write(lout,*) "DYNK> dynk_parseFUN():FILELIN"
               write(lout,*) "DYNK> Error reading file '"//
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
               write(lout,*) "DYNK> Error in getfields_split"
               call prror(-1)
            end if
            
            if ( filefields_nfields  .ne. 2 ) then
               write(lout,*) "DYNK> dynk_parseFUN():FILELIN"
               write(lout,*) "DYNK> Error reading file '"//
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
               write(lout,*) "DYNK> expected 2 fields, got",
     &              filefields_nfields, "ch =",ch
              call prror(-1)
            end if

            x = round_near(errno, filefields_lfields(1)+1,
     &           filefields_fields(1) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,1,x)
            y = round_near(errno, filefields_lfields(2)+1,
     &           filefields_fields(2) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,2,y)
!            write(*,*) "DBGDBG: ch=",ch
!            write(*,*) "DBGDBG: filefields_fields(1)=",
!     &           filefields_fields(1)
!            write(*,*) "DBGDBG: filefields_fields(2)=",
!     &           filefields_fields(2)
+ei
!            write(*,*) "DBGDBG: x,y = ",x,y

            !Current line number
            ii = ii+1
            
            fexpr_dynk(nfexpr_dynk + ii    ) = x
            fexpr_dynk(nfexpr_dynk + ii + t) = y
         enddo
         
         nfexpr_dynk = nfexpr_dynk + 2*t
         funcs_dynk(nfuncs_dynk,5) = t
         close(664)
         
      case ("PIPE")
         ! PIPE: Use a pair of UNIX FIFOs.
         ! Another program is expected to hook onto the other end of the pipe,
         ! and will recieve a message when SixTrack's dynk_computeFUN() is called.
         ! That program should then send a value back (in ASCII), which will be the new setting.
         
         call dynk_checkargs(getfields_nfields,7,
     &        "FUN funname PIPE inPipeName outPipeName ID fileUnit" )
         call dynk_checkspace(1,0,4)
         
+if cr
         write(lout,*) "DYNK FUN PIPE not supported in CR version"
         write(lout,*) "Sorry :("
         call prror(-1)
+ei
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         niexpr_dynk = niexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk   !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 3             !TYPE (PIPE)
         funcs_dynk(nfuncs_dynk,3) = niexpr_dynk   !UnitNR (set below)
         funcs_dynk(nfuncs_dynk,4) = -1            !Not used
         funcs_dynk(nfuncs_dynk,5) = -1            !Not used
         
         !Sanity checks
         if (getfields_lfields(4) .gt. maxstrlen_dynk-1 .or.
     &       getfields_lfields(5) .gt. maxstrlen_dynk-1 .or.
     &       getfields_lfields(6) .gt. maxstrlen_dynk-1      ) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN PIPE got one or more strings which "
            write (lout,*) "was too long (>",maxstrlen_dynk-1,")"
            write (lout,*) "Strings: '",
     &           getfields_fields(4)(1:getfields_lfields(4)),"' and '",
     &           getfields_fields(5)(1:getfields_lfields(5)),"' and '",
     &           getfields_fields(6)(1:getfields_lfields(6)),"'."
            write (lout,*) "lengths =",
     &           getfields_lfields(4),", ",
     &           getfields_lfields(5)," and ",
     &           getfields_lfields(6)
            write (lout,*) "*************************************"
            call prror(51)
         endif

         ! Store data
         cexpr_dynk(ncexpr_dynk  )(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         cexpr_dynk(ncexpr_dynk+1)(1:getfields_lfields(4)) = !inPipe
     &        getfields_fields(4)(1:getfields_lfields(4))
         cexpr_dynk(ncexpr_dynk+2)(1:getfields_lfields(5)) = !outPipe
     &        getfields_fields(5)(1:getfields_lfields(5))
         cexpr_dynk(ncexpr_dynk+3)(1:getfields_lfields(6)) = !ID
     &        getfields_fields(6)(1:getfields_lfields(6))
         ncexpr_dynk = ncexpr_dynk+3
         
         read(getfields_fields(7)(1:getfields_lfields(7)),*) !fileUnit
     &        iexpr_dynk(niexpr_dynk)
         
         ! Look if the fileUnit or filenames are used in a different FUN PIPE
         t=0 !Used to hold the index of the other pipe; t=0 if no older pipe -> open files.
         do ii=1,nfuncs_dynk-1
            if (funcs_dynk(ii,2) .eq. 3) then !It's a PIPE
               !Does any of the settings match?
               if ( iexpr_dynk(funcs_dynk(ii,3)).eq.      !Unit number
     &              iexpr_dynk(niexpr_dynk)           .or.
     &              cexpr_dynk(funcs_dynk(ii,1)+1).eq.    !InPipe filename
     &              cexpr_dynk(ncexpr_dynk-2)         .or.
     &              cexpr_dynk(funcs_dynk(ii,1)+2).eq.    !OutPipe filename
     &              cexpr_dynk(ncexpr_dynk-1)         ) then
                  !Does *all* of the settings match?
                  if ( iexpr_dynk(funcs_dynk(ii,3)).eq.   !Unit number
     &                 iexpr_dynk(niexpr_dynk)           .and.
     &                 cexpr_dynk(funcs_dynk(ii,1)+1).eq. !InPipe filename
     &                 cexpr_dynk(ncexpr_dynk-2)         .and.
     &                 cexpr_dynk(funcs_dynk(ii,1)+2).eq. !OutPipe filename
     &                 cexpr_dynk(ncexpr_dynk-1)         ) then
                     t=ii
                     write(lout,*) "DYNK> "//
     &                    "PIPE FUN '" //
     & trim(stringzerotrim(cexpr_dynk(funcs_dynk(nfuncs_dynk,1)))) //
     & "' using same settings as previously defined FUN '"   //
     & trim(stringzerotrim(cexpr_dynk(funcs_dynk(ii,1)))) //
     & "' -> reusing files !"
                     if (cexpr_dynk(funcs_dynk(ii,1)+3).eq. !ID
     &                   cexpr_dynk(ncexpr_dynk)           ) then
                        write(lout,*) "DYNK> "//
     &               "ERROR: IDs must be different when sharing PIPEs."
                        call prror(-1)
                     endif
                     exit !break loop
                  else !Partial match
      ! Nested too deep, sorry about crappy alignment...
      write(lout,*) "DYNK> *** Error in dynk_parseFUN():PIPE ***"
      write(lout,*) "DYNK> Partial match of inPipe/outPipe/unit number"
      write(lout,*) "DYNK> between PIPE FUN '"               //
     &     trim(stringzerotrim(cexpr_dynk(funcs_dynk(nfuncs_dynk,1))))//
     &     "' and '" //
     &     trim(stringzerotrim(cexpr_dynk(funcs_dynk(ii,1)))) // "'"
                     call prror(-1)
                  endif
               endif
            endif
         end do

         if (t.eq.0) then !Must open a new set of files
         ! Open the inPipe
         inquire( unit=iexpr_dynk(niexpr_dynk), opened=lopen )
         if (lopen) then
            write(lout,*)"DYNK> **** ERROR in dynk_parseFUN():PIPE ****"
            write(lout,*)"DYNK> unit",iexpr_dynk(niexpr_dynk),
     &           "for file '"//
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk-2)))
     &           //"' was already taken"

            call prror(-1)
         end if
         
         write(lout,*) "DYNK> Opening input pipe '"//
     &trim(stringzerotrim(
     &cexpr_dynk(ncexpr_dynk-2)))//"' for FUN '"//
     &trim(stringzerotrim(
     &cexpr_dynk(ncexpr_dynk-3)))//"', ID='"//
     &trim(stringzerotrim(
     &cexpr_dynk(ncexpr_dynk)))//"'"

         ! DYNK PIPE does not support the CR version, so BOINC support (call boincrf()) isn't needed
         open(unit=iexpr_dynk(niexpr_dynk),
     &        file=cexpr_dynk(ncexpr_dynk-2),action='read',
     &        iostat=stat,status="OLD")
         if (stat .ne. 0) then
            write(lout,*) "DYNK> dynk_parseFUN():PIPE"
            write(lout,*) "DYNK> Error opening file '" //
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk-2))) //
     &           "' stat=",stat
            call prror(51)
         endif

         ! Open the outPipe
         write(lout,*) "DYNK> Opening output pipe '"//
     &trim(stringzerotrim(
     &cexpr_dynk(ncexpr_dynk-1)))//"' for FUN '"//
     &trim(stringzerotrim(
     &cexpr_dynk(ncexpr_dynk-3)))//"', ID='"//
     &trim(stringzerotrim(
     &cexpr_dynk(ncexpr_dynk)))//"'"

         inquire( unit=iexpr_dynk(niexpr_dynk)+1, opened=lopen )
         if (lopen) then
            write(lout,*)"DYNK> **** ERROR in dynk_parseFUN():PIPE ****"
            write(lout,*)"DYNK> unit",iexpr_dynk(niexpr_dynk)+1,
     &           "for file '"//
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk-1)))
     &           //"' was already taken"

            call prror(-1)
         end if
         
         ! DYNK PIPE does not support the CR version, so BOINC support (call boincrf()) isn't needed
         open(unit=iexpr_dynk(niexpr_dynk)+1,
     &        file=cexpr_dynk(ncexpr_dynk-1),action='write',
     &        iostat=stat,status="OLD")
         if (stat .ne. 0) then
            write(lout,*) "DYNK> dynk_parseFUN():PIPE"
            write(lout,*) "DYNK> Error opening file '" //
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk-1))) //
     &           "' stat=",stat
            call prror(51)
         endif
         write(iexpr_dynk(niexpr_dynk)+1,'(a)')
     &        "DYNKPIPE !******************!" !Once per file
         endif !End "if (t.eq.0)"/must open new files
         write(iexpr_dynk(niexpr_dynk)+1,'(a)') !Once per ID
     &        "INIT ID="//
     &        trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))
     &        //" for FUN="//
     &        trim(stringzerotrim(cexpr_dynk(ncexpr_dynk-3)))
         
         
      case ("RANDG")
         ! RANDG: Gausian random number with mu, sigma, and optional cutoff
         
         call dynk_checkargs(getfields_nfields,8,
     &        "FUN funname RANDG seed1 seed2 mu sigma cut" )
         call dynk_checkspace(5,2,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         niexpr_dynk = niexpr_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 6           !TYPE (RANDG)
         funcs_dynk(nfuncs_dynk,3) = niexpr_dynk !seed1(initial), seed2(initial), mcut, seed1(current), seed2(current) (in iexpr_dynk)
         funcs_dynk(nfuncs_dynk,4) = nfexpr_dynk !mu, sigma (in fexpr_dynk)
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        iexpr_dynk(niexpr_dynk) ! seed1 (initial)
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        iexpr_dynk(niexpr_dynk+1) ! seed2 (initial)
+if .not.crlibm
         read(getfields_fields(6)(1:getfields_lfields(6)),*)
     &        fexpr_dynk(nfexpr_dynk) ! mu
         read(getfields_fields(7)(1:getfields_lfields(7)),*)
     &        fexpr_dynk(nfexpr_dynk+1) ! sigma
+ei
+if crlibm
         fexpr_dynk(nfexpr_dynk) = round_near(errno, ! mu
     &        getfields_lfields(6)+1, getfields_fields(6) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,6,
     &                       fexpr_dynk(nfexpr_dynk)  )

         fexpr_dynk(nfexpr_dynk+1) = round_near(errno, ! sigma
     &        getfields_lfields(7)+1, getfields_fields(7) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,7,
     &                       fexpr_dynk(nfexpr_dynk+1) )
+ei
         read(getfields_fields(8)(1:getfields_lfields(8)),*)
     &        iexpr_dynk(niexpr_dynk+2) ! mcut

         iexpr_dynk(niexpr_dynk+3) = 0 ! seed1 (current)
         iexpr_dynk(niexpr_dynk+4) = 0 ! seed2 (current)

         niexpr_dynk = niexpr_dynk+4
         nfexpr_dynk = nfexpr_dynk+1

         if (iexpr_dynk(funcs_dynk(nfuncs_dynk,3)+2) .lt. 0) then
            !mcut < 0
            write (lout,*) "DYNK> dynk_parseFUN():RANDG"
            write (lout,*) "DYNK> ERROR in DYNK block parsing (fort.3)"
            write (lout,*) "DYNK> mcut must be >= 0"
            call prror(51)
         endif
         
      case ("RANDU")
         ! RANDU: Uniform random number
         
         call dynk_checkargs(getfields_nfields,5,
     &        "FUN funname RANDU seed1 seed2" )
         call dynk_checkspace(4,0,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         niexpr_dynk = niexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 7           !TYPE (RANDU)
         funcs_dynk(nfuncs_dynk,3) = niexpr_dynk !seed1(initial), seed2(initial), seed1(current), seed2(current)
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        iexpr_dynk(niexpr_dynk) ! seed1 (initial)
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        iexpr_dynk(niexpr_dynk+1) ! seed2 (initial)

         iexpr_dynk(niexpr_dynk+2) = 0 ! seed1 (current)
         iexpr_dynk(niexpr_dynk+3) = 0 ! seed2 (current)

         niexpr_dynk = niexpr_dynk+3

      case("RANDON")
         ! RANDON: Turn by turn ON for one turn with the probability P, else OFF
         call dynk_checkargs(getfields_nfields,6,
     &        "FUN funname RANDON seed1 seed2 P" )
         call dynk_checkspace(4,1,1)
	          
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         niexpr_dynk = niexpr_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1

         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 8           !TYPE (RANDON)
         funcs_dynk(nfuncs_dynk,3) = niexpr_dynk !seed1(initial), seed2(initial), seed1(current), seed2(current)
         funcs_dynk(nfuncs_dynk,4) = nfexpr_dynk !P (in fexpr_dynk)
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG2 (unused)
         
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))

         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        iexpr_dynk(niexpr_dynk)   ! seed1 (initial)
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        iexpr_dynk(niexpr_dynk+1) ! seed2 (initial)
         read(getfields_fields(6)(1:getfields_lfields(6)),*)
     &        fexpr_dynk(nfexpr_dynk)   ! P

         iexpr_dynk(niexpr_dynk+2) = 0 ! seed1 (current)
         iexpr_dynk(niexpr_dynk+3) = 0 ! seed2 (current)

         niexpr_dynk = niexpr_dynk+3         
         
      case("FIR","IIR")
         ! FIR: Finite Impulse Response filter
         ! y[n] = \sum_{i=0}^N b_i*x[n-i]
         ! where N is the order of the filter, x[] is the results from
         ! previous calls to the input function, and b_i is a set of coefficients.
         ! The coefficients are loaded from an ASCII file, formatted with three columns,
         ! the first one being the index 0...N, the second being the coefficients b_0...b_N,
         ! and the third one being the initial values of x[n]..x[n-N].
         ! When running, the values x[n]...x[n-N] are the N last results from calling baseFUN.
         ! Note that this means that at the first call, x[n-0] is pushed into x[n-1] etc.,
         ! and x[n-N] is deleted; i.e. the initial x[n-N] is never used.
         !
         ! Format in fexpr_dynk:
         ! b_0 <- funcs_dynk(<this>,3)
         ! x[n]
         ! x_init[n] (holds the x[n]s from the input file, used to reset the FIR at the first turn)
         ! b_1
         ! x[n-1]
         ! x_init[n-1]
         ! (etc., repeat funcs_dynk(<this>,4)+1 times)
         !
         ! IIR: Infinite Impulse Response filter
         ! y[n] = \sum_{i=0}^N b_i*x[n-i] \sum_{i=1}^M a_i*y[i-n]
         ! where N=M. This is the same as FIR, except that it also uses
         ! previous values of it's own output.
         ! The input file is also identical, except adding two extra columns:
         ! One for the coefficients a_0...a_N, and one for the
         ! initial values of y[n]...y[n-N]. For both these columns,
         ! the first row (a_0 and y[n]) are ignored.
         ! For the first of these columns, the first value (a_0) is ignored and never used,
         ! while y[n-0] is pushed into y[n-1] at the first evaluation,
         ! such that the initial x[n-N] is never used (just like for x[n-N]).
         ! 
         ! Format in fexpr_dynk:
         ! b_0 <- funcs_dynk(<this>,3)
         ! x[n]
         ! x_init[n]
         ! a_0  (a_0 is never used)
         ! y[n] (zeroed for computation, used to hold previously returned value)
         ! y_init[n] (holds the y[n]s from the input file, used to reset the FIR at the first turn)
         ! b_1
         ! x[n-1]
         ! x_init[n-1]
         ! a_1
         ! y[n-1]
         ! y_init[n-1]
         ! (etc., repeat funcs_dynk(<this>,4) times)


         call dynk_checkargs(getfields_nfields,6,
     &        "FUN funname {FIR|IIR} N filename baseFUN")
         select case( getfields_fields(3)(1:getfields_lfields(3)) )
         case("FIR")
            isFIR = .true.
         case("IIR")
            isFIR = .false.
         case default
            write (lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
            write (lout,*) "DYNK> non-recognized type in inner switch?"
            write (lout,*) "DYNK> Got: '" //
     &           getfields_fields(3)(1:getfields_lfields(3)) // "'"
            call prror(-1)
         end select
         
         read(getfields_fields(4)(1:getfields_lfields(4)),*) t ! N
         if (isFIR) then
            call dynk_checkspace(0,3*(t+1),2)
         else
            call dynk_checkspace(0,6*(t+1),2)
         endif
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk   !NAME (in cexpr_dynk)
         if (isFIR) then
            funcs_dynk(nfuncs_dynk,2) = 10 !TYPE (FIR)
         else
            funcs_dynk(nfuncs_dynk,2) = 11 !TYPE (IIR)
         endif
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk+1 !ARG1 (start of float storage)
         funcs_dynk(nfuncs_dynk,4) = t             !ARG2 (filter order N)
         funcs_dynk(nfuncs_dynk,5) =               !ARG3 (filtered function)
     &        dynk_findFUNindex( getfields_fields(6)
     &                           (1:getfields_lfields(6)), 1)
         !Store metadata
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        iexpr_dynk(niexpr_dynk) ! N
         
         ! Sanity check
         if (funcs_dynk(nfuncs_dynk,5).eq.-1) then
            call dynk_dumpdata
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FIR/IIR function wanting function '",
     &            getfields_fields(6)(1:getfields_lfields(6)), "'"
            write (lout,*) "This FUN is unknown!"
            write (lout,*) "*************************************"
            call prror(51)
         endif
        if (getfields_lfields(5) .gt. maxstrlen_dynk-1) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN FIR/IIR got a filename name with "
            write (lout,*) "length =", getfields_lfields(5)
            write (lout,*) "> ",maxstrlen_dynk-1
            write (lout,*) "The name was: '",getfields_fields(5)
     &                                    (1:getfields_lfields(5)),"'"
            write (lout,*) "*************************************"
            call prror(51)
         endif
         if ( iexpr_dynk(niexpr_dynk) .le. 0 ) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "FUN FIR/IIR got N <= 0, this is not valid"
            write (lout,*) "*************************************"
            call prror(51)
         endif
         
         !More metadata
         ncexpr_dynk = ncexpr_dynk+1
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(5)) = !FILE NAME
     &        getfields_fields(5)(1:getfields_lfields(5))
         
         !Read the file
         inquire( unit=664, opened=lopen )
         if (lopen) then
            write(lout,*)
     &           "DYNK> **** ERROR in dynk_parseFUN():FIR/IIR ****"
            write(lout,*)"DYNK> unit 664 for file '"//
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) //
     &           "' was already taken"
            call prror(-1)
         end if
+if boinc
         call boincrf(cexpr_dynk(ncexpr_dynk),filename)
         open(unit=664,file=filename,action='read',
     &        iostat=stat, status="OLD")
+ei
+if .not.boinc
         open(unit=664,file=cexpr_dynk(ncexpr_dynk),action='read',
     &        iostat=stat, status="OLD")
+ei
         if (stat .ne. 0) then
            write(lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
            write(lout,*) "DYNK> Error opening file '" //
     &           trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
            call prror(51)
         endif
         
         do ii=0, funcs_dynk(nfuncs_dynk,4) 
            !Reading the FIR/IIR file without CRLIBM
+if .not.crlibm
            if (isFIR) then
               read(664,*,iostat=stat) t, x, y
            else
               read(664,*,iostat=stat) t, x, y, z, u
            endif
            if (stat.ne.0) then
               write(lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
               write(lout,*) "DYNK> Error reading file '" //
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) // "'"
               write(lout,*) "DYNK> File ended unexpectedly at ii =",ii
               call prror(-1)
            endif
+ei ! END + if .not.crlibm

            !Reading the FIR/IIR file with CRLIBM
+if crlibm
            read(664,'(a)', iostat=stat) ch
            if (stat.ne.0) then
               write(lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
               write(lout,*) "DYNK> Error reading file '"//
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
               write(lout,*) "DYNK> File ended unexpectedly at ii =",ii
               call prror(-1)
            endif
            
            call getfields_split(ch,
     &           filefields_fields, filefields_lfields,
     &           filefields_nfields, filefields_lerr )
            
            !Sanity checks
            if ( filefields_lerr ) then
               write(lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
               write(lout,*) "DYNK> Error reading file '",
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
               write(lout,*) "DYNK> Error in getfields_split()"
               call prror(-1)
            end if
            if ( (      isFIR .and.filefields_nfields .ne. 3) .or.
     &           ((.not.isFIR).and.filefields_nfields .ne. 5)     ) then
               write(lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
               write(lout,*) "DYNK> Error reading file '"//
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk))) //
     &              "', line =", ii
               write(lout,*) "DYNK> Expected 3[5] fields ",
     &              "(idx, fac, init, selfFac, selfInit), ",
     &              "got ",filefields_nfields
               call prror(-1)
            endif
            
            !Read the data into t,x,y(,z,u):
            read(filefields_fields(1)(1:filefields_lfields(1)),*) t
            
            x = round_near(errno, filefields_lfields(2)+1,
     &           filefields_fields(2) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,2,x)
            
            y = round_near(errno, filefields_lfields(3)+1,
     &           filefields_fields(3) )
            if (errno.ne.0)
     &           call rounderr(errno,filefields_fields,3,y)
            
            if (.not.isFIR) then
               z = round_near(errno, filefields_lfields(4)+1,
     &              filefields_fields(4) )
               if (errno.ne.0)
     &              call rounderr(errno,filefields_fields,4,z)
               
               u = round_near(errno, filefields_lfields(5)+1,
     &              filefields_fields(5) )
               if (errno.ne.0)
     &              call rounderr(errno,filefields_fields,5,u)
            endif
            
+ei ! END +if crlibm

            ! More sanity checks
            if (t .ne. ii) then
               write(lout,*) "DYNK> dynk_parseFUN():FIR/IIR"
               write(lout,*) "DYNK> Error reading file '"//
     &              trim(stringzerotrim(cexpr_dynk(ncexpr_dynk)))//"'"
               write(lout,*) "DYNK> Got line t =",t, ", expected ", ii
               call prror(-1)
            endif
            !Save data to arrays
            !Store coefficients (x) and initial/earlier values (y) in interlaced order
            nfexpr_dynk = nfexpr_dynk+1
            fexpr_dynk(nfexpr_dynk) = x      ! b_i
            nfexpr_dynk = nfexpr_dynk+1
            fexpr_dynk(nfexpr_dynk) = 0.0    ! x[n-1], will be initialized in dynk_apply()
            nfexpr_dynk = nfexpr_dynk+1
            fexpr_dynk(nfexpr_dynk) = y      ! x_init[n-i]
            if (.not.isFIR) then
               nfexpr_dynk = nfexpr_dynk+1
               fexpr_dynk(nfexpr_dynk) = z   ! a_i
               nfexpr_dynk = nfexpr_dynk+1
               fexpr_dynk(nfexpr_dynk) = 0.0 ! y[n-i], will be initialized in dynk_apply()
               nfexpr_dynk = nfexpr_dynk+1
               fexpr_dynk(nfexpr_dynk) = u   ! y_init[n-i]
            endif
         enddo
         close(664)

      !!! Operators: #20-39 !!!
      case("ADD","SUB","MUL","DIV","POW")
         ! Two-argument operators  y = OP(f1, f2)

         call dynk_checkargs(getfields_nfields,5,
     &        "FUN funname {ADD|SUB|MUL|DIV|POW} funname1 funname2")
         call dynk_checkspace(0,0,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         select case (getfields_fields(3)(1:getfields_lfields(3)))
         case ("ADD")
            funcs_dynk(nfuncs_dynk,2) = 20 !TYPE (ADD)
         case ("SUB")
            funcs_dynk(nfuncs_dynk,2) = 21 !TYPE (SUB)
         case ("MUL")
            funcs_dynk(nfuncs_dynk,2) = 22 !TYPE (MUL)
         case ("DIV")
            funcs_dynk(nfuncs_dynk,2) = 23 !TYPE (DIV)
         case ("POW")
            funcs_dynk(nfuncs_dynk,2) = 24 !TYPE (POW)
         case default
            write (lout,*) "DYNK> dynk_parseFUN() : 2-arg function"
            write (lout,*) "DYNK> non-recognized type in inner switch"
            write (lout,*) "DYNK> Got: '" //
     &           getfields_fields(3)(1:getfields_lfields(3)) // "'"
            call prror(51)
         end select
         funcs_dynk(nfuncs_dynk,3) = 
     &        dynk_findFUNindex( getfields_fields(4)
     &                           (1:getfields_lfields(4)), 1) !Index to f1
         funcs_dynk(nfuncs_dynk,4) = 
     &        dynk_findFUNindex( getfields_fields(5)
     &                           (1:getfields_lfields(5)), 1) !Index to f2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         ! Sanity check (string lengths are done inside dynk_findFUNindex)
         if (funcs_dynk(nfuncs_dynk,3) .eq. -1 .or. 
     &       funcs_dynk(nfuncs_dynk,4) .eq. -1) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "TWO ARG OPERATOR wanting functions '",
     &           getfields_fields(4)(1:getfields_lfields(4)), "' and '", 
     &           getfields_fields(5)(1:getfields_lfields(5)), "'"
            write (lout,*) "Calculated indices:",
     &           funcs_dynk(nfuncs_dynk,3), funcs_dynk(nfuncs_dynk,4)
            write (lout,*) "One or both of these are not known (-1)."
            write (lout,*) "*************************************"
            call dynk_dumpdata
            call prror(51)
         end if

      case ("MINUS","SQRT","SIN","COS","LOG","LOG10","EXP")
         ! One-argument operators  y = OP(f1)

         call dynk_checkargs(getfields_nfields,4,
     &        "FUN funname {MINUS|SQRT|SIN|COS|LOG|LOG10|EXP} funname")
         call dynk_checkspace(0,0,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         select case ( getfields_fields(3)(1:getfields_lfields(3)) )
         case ("MINUS")
            funcs_dynk(nfuncs_dynk,2) = 30 !TYPE (MINUS)
         case ("SQRT")
            funcs_dynk(nfuncs_dynk,2) = 31 !TYPE (SQRT)
         case ("SIN")
            funcs_dynk(nfuncs_dynk,2) = 32 !TYPE (SIN)
         case ("COS")
            funcs_dynk(nfuncs_dynk,2) = 33 !TYPE (COS)
         case ("LOG")
            funcs_dynk(nfuncs_dynk,2) = 34 !TYPE (LOG)
         case ("LOG10")
            funcs_dynk(nfuncs_dynk,2) = 35 !TYPE (LOG10)
         case ("EXP")
            funcs_dynk(nfuncs_dynk,2) = 36 !TYPE (EXP)
         case default
            write (lout,*) "DYNK> dynk_parseFUN() : 1-arg function"
            write (lout,*) "DYNK> non-recognized type in inner switch?"
            write (lout,*) "DYNK> Got: '" //
     &           getfields_fields(3)(1:getfields_lfields(3)) // "'"
            call prror(51)
         end select
         funcs_dynk(nfuncs_dynk,3) = 
     &        dynk_findFUNindex(getfields_fields(4)
     &        (1:getfields_lfields(4)), 1)       !Index to f1
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         ! Sanity check (string lengths are done inside dynk_findFUNindex)
         if (funcs_dynk(nfuncs_dynk,3) .eq. -1) then
            write (lout,*) "*************************************"
            write (lout,*) "ERROR in DYNK block parsing (fort.3):"
            write (lout,*) "SINGLE OPERATOR FUNC wanting function '",
     &           getfields_fields(4)(1:getfields_lfields(4)), "'"
            write (lout,*) "Calculated index:",
     &           funcs_dynk(nfuncs_dynk,3)
            write (lout,*) "One or both of these are not known (-1)."
            write (lout,*) "*************************************"
            call dynk_dumpdata
            call prror(51)
         end if

      !!! Polynomial & Elliptical functions: # 40-59 !!!
      case("CONST")   
         ! CONST: Just a constant value
         
         call dynk_checkargs(getfields_nfields,4,
     &        "FUN funname CONST value" )
         call dynk_checkspace(0,1,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 40          !TYPE (CONST)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))

+if .not.crlibm
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        fexpr_dynk(nfexpr_dynk) ! value
+ei
+if crlibm
         fexpr_dynk(nfexpr_dynk) = round_near(errno, ! value
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4,
     &                       fexpr_dynk(nfexpr_dynk)  )
+ei

      case ("TURN")
         ! TURN: Just the current turn number
         
         call dynk_checkargs(getfields_nfields,3,
     &        "FUN funname TURN" )
         call dynk_checkspace(0,0,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 41          !TYPE (TURN)
         funcs_dynk(nfuncs_dynk,3) = -1          !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))

      case ("LIN")
         ! LIN: Linear ramp y = dy/dt*T+b
         
         call dynk_checkargs(getfields_nfields,5,
     &        "FUN funname LIN dy/dt b" )
         call dynk_checkspace(0,2,1)

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 42          !TYPE (LIN)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))

+if .not.crlibm
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        fexpr_dynk(nfexpr_dynk) ! dy/dt
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        fexpr_dynk(nfexpr_dynk+1) ! b
+ei
+if crlibm
         fexpr_dynk(nfexpr_dynk) = round_near(errno, ! dy/dt
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4,
     &                       fexpr_dynk(nfexpr_dynk)   )
         fexpr_dynk(nfexpr_dynk+1) = round_near(errno, ! b
     &        getfields_lfields(5)+1, getfields_fields(5) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,5,
     &                       fexpr_dynk(nfexpr_dynk+1) )
+ei
         nfexpr_dynk = nfexpr_dynk + 1

      case ("LINSEG")
         ! LINSEG: Linear ramp between points (x1,y1) and (x2,y2)
         
         call dynk_checkargs(getfields_nfields,7,
     &        "FUN funname LINSEG x1 x2 y1 y2" )
         call dynk_checkspace(0,4,1)

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 43          !TYPE (LINSEG)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
+if .not.crlibm
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        fexpr_dynk(nfexpr_dynk)   ! x1
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        fexpr_dynk(nfexpr_dynk+1) ! x2
         read(getfields_fields(6)(1:getfields_lfields(6)),*)
     &        fexpr_dynk(nfexpr_dynk+2) ! y1
         read(getfields_fields(7)(1:getfields_lfields(7)),*)
     &        fexpr_dynk(nfexpr_dynk+3) ! y2
+ei
+if crlibm
         fexpr_dynk(nfexpr_dynk) = round_near(errno, ! x1
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4,
     &                       fexpr_dynk(nfexpr_dynk)   )
         fexpr_dynk(nfexpr_dynk+1) = round_near(errno, ! x2
     &        getfields_lfields(5)+1, getfields_fields(5) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,5,
     &                       fexpr_dynk(nfexpr_dynk+1)   )
         fexpr_dynk(nfexpr_dynk+2) = round_near(errno, ! y1
     &        getfields_lfields(6)+1, getfields_fields(6) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,6,
     &                       fexpr_dynk(nfexpr_dynk+2)   )
         fexpr_dynk(nfexpr_dynk+3) = round_near(errno, ! y2
     &        getfields_lfields(7)+1, getfields_fields(7) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,7,
     &                       fexpr_dynk(nfexpr_dynk+3)   )
+ei
         nfexpr_dynk = nfexpr_dynk + 3
         
         if (fexpr_dynk(nfexpr_dynk-3).eq.fexpr_dynk(nfexpr_dynk-2))then
            write (lout,*) "ERROR in DYNK block parsing (fort.3)"
            write (lout,*) "LINSEG: x1 and x2 must be different."
            call prror(51)
         endif
         
      case ("QUAD")
         ! QUAD: Quadratic ramp y = a*T^2 + b*T + c
         
         call dynk_checkargs(getfields_nfields,6,
     &        "FUN funname QUAD a b c" )
         call dynk_checkspace(0,3,1)

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 44          !TYPE (QUAD)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))

+if .not.crlibm
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        fexpr_dynk(nfexpr_dynk)   ! a
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        fexpr_dynk(nfexpr_dynk+1) ! b
         read(getfields_fields(6)(1:getfields_lfields(6)),*)
     &        fexpr_dynk(nfexpr_dynk+2) ! c
+ei
+if crlibm
         fexpr_dynk(nfexpr_dynk) = round_near(errno, ! a
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4,
     &                       fexpr_dynk(nfexpr_dynk)   )
         fexpr_dynk(nfexpr_dynk+1) = round_near(errno, ! b
     &        getfields_lfields(5)+1, getfields_fields(5) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,5,
     &                       fexpr_dynk(nfexpr_dynk+1)   )
         fexpr_dynk(nfexpr_dynk+2) = round_near(errno, ! c
     &        getfields_lfields(6)+1, getfields_fields(6) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,6,
     &                       fexpr_dynk(nfexpr_dynk+2)   )
+ei
         nfexpr_dynk = nfexpr_dynk + 2

      case ("QUADSEG")
         ! QUADSEG: Quadratic ramp y = a*T^2 + b*T + c,
         ! input as start point (x1,y1), end point (x2,y2), derivative at at x1
         
         call dynk_checkargs(getfields_nfields,8,
     &        "FUN funname QUADSEG x1 x2 y1 y2 deriv" )
         call dynk_checkspace(0,8,1)

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 45          !TYPE (QUADSEG)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
+if .not.crlibm
         read(getfields_fields(4)(1:getfields_lfields(4)),*) x1
         read(getfields_fields(5)(1:getfields_lfields(5)),*) x2
         read(getfields_fields(6)(1:getfields_lfields(6)),*) y1
         read(getfields_fields(7)(1:getfields_lfields(7)),*) y2
         read(getfields_fields(8)(1:getfields_lfields(8)),*) deriv
+ei
+if crlibm
         x1 = round_near(errno, ! x1
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4, x1 )
         x2 = round_near(errno, ! x2
     &        getfields_lfields(5)+1, getfields_fields(5) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,5, x2 )
         y1 = round_near(errno, ! y1
     &        getfields_lfields(6)+1, getfields_fields(6) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,6, y1 )
         y2 = round_near(errno, ! y2
     &        getfields_lfields(7)+1, getfields_fields(7) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,7, y2 )
         deriv = round_near(errno, ! deriv
     &        getfields_lfields(8)+1, getfields_fields(8) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,8, deriv )
+ei
         if (x1 .eq. x2) then
            write (lout,*) "ERROR in DYNK block parsing (fort.3)"
            write (lout,*) "QUADSEG: x1 and x2 must be different."
            call prror(51)
         endif
         
         ! Compute a:
         fexpr_dynk(nfexpr_dynk) = deriv/(x1-x2)
     &        + (y2-y1)/((x1-x2)**2)
         ! Compute b:
         fexpr_dynk(nfexpr_dynk+1) = (y2-y1)/(x2-x1)
     &        - (x1+x2)*fexpr_dynk(nfexpr_dynk)
         ! Compute c:
         fexpr_dynk(nfexpr_dynk+2) = y1 + (
     &        - x1**2 * fexpr_dynk(nfexpr_dynk)
     &        - x1    * fexpr_dynk(nfexpr_dynk+1) )
         
         ! Store input data:
         fexpr_dynk(nfexpr_dynk+3) = x1
         fexpr_dynk(nfexpr_dynk+4) = x2
         fexpr_dynk(nfexpr_dynk+5) = y1
         fexpr_dynk(nfexpr_dynk+6) = y2
         fexpr_dynk(nfexpr_dynk+7) = deriv

         nfexpr_dynk = nfexpr_dynk + 7
         
      !!! Trancedental functions: #60-79 !!!
      case ("SINF","COSF","COSF_RIPP")
         ! SINF     : Sin functions y = A*sin(omega*T+phi)
         ! COSF     : Cos functions y = A*cos(omega*T+phi)
         ! COSF_RIPP: Cos functions y = A*cos(2*pi*(T-1)/period+phi)
         
         call dynk_checkargs(getfields_nfields,6,
     &        "FUN funname {SINF|COSF|COSF_RIPP} "//
     &        "amplitude {omega|period} phase" )
         call dynk_checkspace(0,3,1)

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         select case (getfields_fields(3)(1:getfields_lfields(3)))
         case("SINF")
            funcs_dynk(nfuncs_dynk,2) = 60       !TYPE (SINF)
         case("COSF")
            funcs_dynk(nfuncs_dynk,2) = 61       !TYPE (COSF)
         case ("COSF_RIPP")
            funcs_dynk(nfuncs_dynk,2) = 62       !TYPE (COSF_RIPP)
         case default
            write (lout,*) "DYNK> dynk_parseFUN() : SINF/COSF"
            write (lout,*) "DYNK> non-recognized type in inner switch"
            write (lout,*) "DYNK> Got: '" //
     &           getfields_fields(3)(1:getfields_lfields(3)) // "'"
            call prror(51)
         end select
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         
+if .not.crlibm
         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        fexpr_dynk(nfexpr_dynk) !A
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        fexpr_dynk(nfexpr_dynk+1) !omega
         read(getfields_fields(6)(1:getfields_lfields(6)),*)
     &        fexpr_dynk(nfexpr_dynk+2) !phi
+ei
+if crlibm
         fexpr_dynk(nfexpr_dynk) = round_near(errno, ! A
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4,
     &                       fexpr_dynk(nfexpr_dynk)   )
         fexpr_dynk(nfexpr_dynk+1) = round_near(errno, ! omega
     &        getfields_lfields(5)+1, getfields_fields(5) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,5,
     &                       fexpr_dynk(nfexpr_dynk+1)   )
         fexpr_dynk(nfexpr_dynk+2) = round_near(errno, ! phi
     &        getfields_lfields(6)+1, getfields_fields(6) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,6,
     &                       fexpr_dynk(nfexpr_dynk+2)   )
+ei
         nfexpr_dynk = nfexpr_dynk + 2

      case ("PELP")
         ! PELP: Parabolic/exponential/linear/parabolic
         ! From "Field Computation for Accelerator Magnets:
         ! Analytical and Numerical Methods for Electromagnetic Design and Optimization"
         ! By Dr.-Ing. Stephan Russenschuck
         ! Appendix C: "Ramping the LHC Dipoles"
         
         call dynk_checkargs(getfields_nfields,10,
     &        "FUN funname PELP tinj Iinj Inom A D R te" )
         call dynk_checkspace(0,13,1) !!...

         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         nfexpr_dynk = nfexpr_dynk+1
         ncexpr_dynk = ncexpr_dynk+1
         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 80          !TYPE (PELP)
         funcs_dynk(nfuncs_dynk,3) = nfexpr_dynk !ARG1
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))
         
         !Read and calculate parameters
+if .not.crlibm
         read(getfields_fields(4) (1:getfields_lfields( 4)),*) tinj
         read(getfields_fields(5) (1:getfields_lfields( 5)),*) Iinj
         read(getfields_fields(6) (1:getfields_lfields( 6)),*) Inom
         read(getfields_fields(7) (1:getfields_lfields( 7)),*) A
         read(getfields_fields(8) (1:getfields_lfields( 8)),*) D
         read(getfields_fields(9) (1:getfields_lfields( 9)),*) R
         read(getfields_fields(10)(1:getfields_lfields(10)),*) te
+ei
+if crlibm
         tinj = round_near(errno,    ! tinj
     &        getfields_lfields(4)+1, getfields_fields(4) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,4, tinj )
         Iinj = round_near(errno,    ! Iinj
     &        getfields_lfields(5)+1, getfields_fields(5) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,5, Iinj )
         Inom = round_near(errno,    ! Inom
     &        getfields_lfields(6)+1, getfields_fields(6) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,6, Inom )
         A = round_near(errno,       ! A
     &        getfields_lfields(7)+1, getfields_fields(7) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,7, A )
         D = round_near(errno,       ! D
     &        getfields_lfields(8)+1, getfields_fields(8) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,8, D )
         R = round_near(errno,       ! R
     &        getfields_lfields(9)+1, getfields_fields(9) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,9, R )
         te = round_near(errno,      ! te
     &        getfields_lfields(10)+1, getfields_fields(10) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,10, te )
+ei
         derivI_te = A*(te-tinj)                 ! nostore
         I_te      = (A/2.0)*(te-tinj)**2 + Iinj ! nostore
         bexp      = derivI_te/I_te
         aexp      = exp(-bexp*te)*I_te
         t1        = log(R/(aexp*bexp))/bexp
         I1        = aexp*exp(bexp*t1)
         td        = (Inom-I1)/R + (t1 - R/(2*D))
         tnom      = td + R/D
         
         if (ldynkdebug) then
         write (lout,*) "DYNKDEBUG> *** PELP SETTINGS: ***"
         write (lout,*) "DYNKDEBUG> tinj =", tinj
         write (lout,*) "DYNKDEBUG> Iinj =", Iinj
         write (lout,*) "DYNKDEBUG> Inom =", Inom
         write (lout,*) "DYNKDEBUG> A    =", A
         write (lout,*) "DYNKDEBUG> D    =", D
         write (lout,*) "DYNKDEBUG> R    =", R
         write (lout,*) "DYNKDEBUG> te   =", te
         write (lout,*) "DYNKDEBUG> "
         write (lout,*) "DYNKDEBUG> derivI_te =", derivI_te
         write (lout,*) "DYNKDEBUG> I_te      =", I_te
         write (lout,*) "DYNKDEBUG> bexp      =", bexp
         write (lout,*) "DYNKDEBUG> aexp      =", aexp
         write (lout,*) "DYNKDEBUG> t1        =", t1
         write (lout,*) "DYNKDEBUG> I1        =", I1
         write (lout,*) "DYNKDEBUG> td        =", td
         write (lout,*) "DYNKDEBUG> tnom      =", tnom
         write (lout,*) "DYNKDEBUG> **********************"
         
         endif
         
         if (.not. (tinj .lt. te .and.
     &                te .lt. t1 .and.
     &                t1 .lt. td .and.
     &                td .lt. tnom ) ) then
            WRITE(lout,*) "DYNK> ********************************"
            WRITE(lout,*) "DYNK> ERROR***************************"
            write(lout,*) "DYNK> PELP: Order of times not correct"
            WRITE(lout,*) "DYNK> ********************************"
            call prror(51)
         endif
         
         !Store: Times
         fexpr_dynk(nfexpr_dynk)    = tinj
         fexpr_dynk(nfexpr_dynk+ 1) = te
         fexpr_dynk(nfexpr_dynk+ 2) = t1
         fexpr_dynk(nfexpr_dynk+ 3) = td
         fexpr_dynk(nfexpr_dynk+ 4) = tnom
         !Store: Parameters / section1 (parabola)
         fexpr_dynk(nfexpr_dynk+ 5) = Iinj
         fexpr_dynk(nfexpr_dynk+ 6) = A
         !Store: Parameters / section2 (exponential)
         fexpr_dynk(nfexpr_dynk+ 7) = aexp
         fexpr_dynk(nfexpr_dynk+ 8) = bexp
         !Store: Parameters / section3 (linear)
         fexpr_dynk(nfexpr_dynk+ 9) = I1
         fexpr_dynk(nfexpr_dynk+10) = R
         !Store: Parameters / section4 (parabola)
         fexpr_dynk(nfexpr_dynk+11) = D
         fexpr_dynk(nfexpr_dynk+12) = Inom
         
         nfexpr_dynk = nfexpr_dynk + 12

      case("ONOFF")
         ! ONOFF: On for p1 turns, then off for the rest of the period p2
         call dynk_checkargs(getfields_nfields,5,
     &        "FUN funname ONOFF p1 p2" )
         call dynk_checkspace(0,0,1)
         
         ! Set pointers to start of funs data blocks
         nfuncs_dynk = nfuncs_dynk+1
         ncexpr_dynk = ncexpr_dynk+1

         ! Store pointers
         funcs_dynk(nfuncs_dynk,1) = ncexpr_dynk !NAME (in cexpr_dynk)
         funcs_dynk(nfuncs_dynk,2) = 81          !TYPE (ONOFF)
         funcs_dynk(nfuncs_dynk,3) = -1          !ARG1 (p1)
         funcs_dynk(nfuncs_dynk,4) = -1          !ARG2 (p2)
         funcs_dynk(nfuncs_dynk,5) = -1          !ARG3 (unused)
         
         ! Store data
         cexpr_dynk(ncexpr_dynk)(1:getfields_lfields(2)) = !NAME
     &        getfields_fields(2)(1:getfields_lfields(2))

         read(getfields_fields(4)(1:getfields_lfields(4)),*)
     &        funcs_dynk(nfuncs_dynk,3) ! p1
         read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &        funcs_dynk(nfuncs_dynk,4) ! p2

         !Check for bad input
         if ( funcs_dynk(nfuncs_dynk,3) .lt. 0 .or.                    ! p1 <  1 ?
     &        funcs_dynk(nfuncs_dynk,4) .le. 1 .or.                    ! p2 <= 1 ?
     &        funcs_dynk(nfuncs_dynk,4) .lt. funcs_dynk(nfuncs_dynk,3) ! p2 < p1 ?
     &        ) then
            write(lout,*)
     &      "DYNK> Error in ONOFF: Expected p1 >= 0, p2 > 1, p1 <= p2"
            call prror(-1)
         end if

      case default
         ! UNKNOWN function
         write (lout,*) "*************************************"
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "Unkown function to dynk_parseFUN()   "
         write (lout,*) "Got fields:"
         do ii=1,getfields_nfields
            write (lout,*) "Field(",ii,") ='",
     &           getfields_fields(ii)(1:getfields_lfields(ii)),"'"
         enddo
         write (lout,*) "*************************************"

         call dynk_dumpdata
         call prror(51)
      end select
      
      end subroutine

      subroutine dynk_checkargs(nfields,nfields_expected,funsyntax)
      implicit none
+ca crcoall
      integer nfields, nfields_expected
      character(*) funsyntax
      intent(in) nfields, nfields_expected, funsyntax
      
      if (nfields .ne. nfields_expected) then
         write (lout,*) "ERROR in DYNK block parsing (fort.3)"
         write (lout,*) "The function expected",nfields_expected,
     &               "arguments, got",nfields
         write (lout,*) "Expected syntax:"
         write (lout,*) funsyntax(:)
         call prror(51)
      endif
      end subroutine

      subroutine dynk_checkspace(iblocks,fblocks,cblocks)
      implicit none
      integer iblocks,fblocks,cblocks
      intent(in) iblocks,fblocks,cblocks

+ca crcoall

      if ( (niexpr_dynk+iblocks .gt. maxdata_dynk) .or.
     &     (nfexpr_dynk+fblocks .gt. maxdata_dynk) .or.
     &     (ncexpr_dynk+cblocks .gt. maxdata_dynk) ) then
         
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "Max number of maxdata_dynk to be exceeded"
         write (lout,*) "niexpr_dynk:", niexpr_dynk
         write (lout,*) "nfexpr_dynk:", nfexpr_dynk
         write (lout,*) "ncexpr_dynk:", ncexpr_dynk
         
         call prror(51)
      endif
      end subroutine
      
      subroutine dynk_parseSET(getfields_fields,
     &     getfields_lfields,getfields_nfields)
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 15-10-2014
!     parse SET lines in the fort.3 input file, 
!     store it in COMMON block dynkComExpr.
!-----------------------------------------------------------------------
      implicit none
+ca comgetfields
+ca stringzerotrim

+ca crcoall

      integer ii
      
      if (nsets_dynk+1 .gt. maxsets_dynk) then
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "Maximum number of SET exceeded, ",
     &               "please increase parameter maxsets_dynk."
         write (lout,*) "Current value of maxsets_dynk:", maxsets_dynk
         call prror(51)
      endif

      if (getfields_nfields .ne. 7) then
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "Expected 7 fields on line while parsing SET."
         write (lout,*) "Correct syntax:"
         write (lout,*) "SET element_name attribute_name function_name",
     &                  " startTurn endTurn turnShift"
         write (lout,*) "got field:"
         do ii=1,getfields_nfields
            write (lout,*) "Field(",ii,") ='",
     &           getfields_fields(ii)(1:getfields_lfields(ii)),"'"
         enddo
         call prror(51)
      endif

      nsets_dynk = nsets_dynk + 1

      sets_dynk(nsets_dynk,1) =
     &     dynk_findFUNindex( getfields_fields(4)
     &     (1:getfields_lfields(4)), 1 ) ! function_name -> function index
      read(getfields_fields(5)(1:getfields_lfields(5)),*)
     &     sets_dynk(nsets_dynk,2) ! startTurn
      read(getfields_fields(6)(1:getfields_lfields(6)),*)
     &     sets_dynk(nsets_dynk,3) ! endTurn
      read(getfields_fields(7)(1:getfields_lfields(7)),*)
     &     sets_dynk(nsets_dynk,4) ! turnShift
      
      !Sanity check on string lengths
      if (getfields_lfields(2).gt.16 .or.
     &    getfields_lfields(2).gt.maxstrlen_dynk-1) then
         write (lout,*) "*************************************"
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "SET got an element name with length =",
     &        getfields_lfields(2), "> 16 or > maxstrlen_dynk-1."
         write (lout,*) "The name was: '",
     &        getfields_fields(2)(1:getfields_lfields(2)),"'"
         write (lout,*) "*************************************"
         call prror(51)
      endif
      
      if (getfields_lfields(3).gt.maxstrlen_dynk-1) then
         write(lout,*) "ERROR in DYNK block parsing (fort.3) (SET):"
         write(lout,*) "The attribute name '"//
     &        getfields_fields(2)(1:getfields_lfields(2))//"'"
         write(lout,*) "is too long! Max length is",
     &        maxstrlen_dynk-1
         call prror(51)         
      endif
      
      !OK -- save them!
      csets_dynk(nsets_dynk,1)(1:getfields_lfields(2)) =
     &     getfields_fields(2)(1:getfields_lfields(2)) ! element_name
      csets_dynk(nsets_dynk,2)(1:getfields_lfields(3)) =
     &     getfields_fields(3)(1:getfields_lfields(3)) ! attribute_name
      
      ! Sanity check
      if (sets_dynk(nsets_dynk,1).eq.-1) then
         write (lout,*) "*************************************"
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "SET wanting function '",
     &        getfields_fields(4)(1:getfields_lfields(4)), "'"
         write (lout,*) "Calculated index:", sets_dynk(nsets_dynk,1)
         write (lout,*) "This function is not known."
         write (lout,*) "*************************************"
         call prror(51)
      endif
      
      if (  (sets_dynk(nsets_dynk,3) .ne. -1) .and. !Not the special case
     &      (sets_dynk(nsets_dynk,2) .gt. sets_dynk(nsets_dynk,3)) )then
         write (lout,*) "*************************************"
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "SET got first turn num > last turn num"
         write (lout,*) "first=",sets_dynk(nsets_dynk,2)
         write (lout,*) "last =",sets_dynk(nsets_dynk,3)
         write (lout,*) "SET #", nsets_dynk
         write (lout,*) "*************************************"
         call prror(51)
      end if
      
      if ( (sets_dynk(nsets_dynk,2) .le. 0 ) .or.
     &     (sets_dynk(nsets_dynk,3) .lt. -1) .or. 
     &     (sets_dynk(nsets_dynk,3) .eq. 0 )     ) then
         write (lout,*) "*************************************"
         write (lout,*) "ERROR in DYNK block parsing (fort.3):"
         write (lout,*) "SET got turn number <= 0 "
         write (lout,*) "(not last = -1 meaning infinity)"
         write (lout,*) "first=",sets_dynk(nsets_dynk,2)
         write (lout,*) "last =",sets_dynk(nsets_dynk,3)
         write (lout,*) "SET #", nsets_dynk
         write (lout,*) "*************************************"
         call prror(51)
      end if

      end subroutine

      integer function dynk_findFUNindex(funName_input, startfrom)
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 14-07-2015
!     Find and return the index in the ifuncs array to the
!      function with name funName, which should be zero-padded.
!     Return -1 if nothing was found.
!
!     Note: It is expected that the length of funName_input is
!      equal or less than maxstrlen_dynk, and if it equal,
!      that it is a zero-terminated string.
!-----------------------------------------------------------------------
      implicit none
+ca crcoall
      character(*) funName_input
      character(maxstrlen_dynk) funName
      integer startfrom
      intent(in) funName_input, startfrom


      integer ii

C      write(*,*)"DBGDBG input: '"//funName_input//"'",len(funName_input)      

      if (len(funName_input).gt.maxstrlen_dynk) then
         write (lout,*) "ERROR in dynk_findFUNindex"
         write (lout,*) "len(funName_input) = ",len(funName_input),
     &        ".gt. maxstrlen_dynk-1 = ", maxstrlen_dynk-1
         call prror(-1)
      endif
      ! If the length is exactly maxstrlen_dynk, it should be zero-terminated.
      if (( len(funName_input).eq.maxstrlen_dynk ) .and.
     &    ( funName_input(len(funName_input):len(funName_input))
     &     .ne.char(0)) ) then
         write (lout,*) "ERROR in dynk_findFUNindex"
         write (lout,*) "Expected funName_input[-1]=NULL"
         call prror(-1)
      endif
      
      do ii=1,len(funName_input)
C         write(*,*) "DBGDBG a:", ii
         funName(ii:ii) = funName_input(ii:ii)
      enddo
      funName(1:len(funName_input)) = funName_input
      do ii=len(funName_input)+1,maxstrlen_dynk
C         write(*,*) "DBGDBG b:", ii
         funName(ii:ii) = char(0)
      enddo
C      write(*,*) "DBGDBG c:", funName, len(funName)

      dynk_findFUNindex = -1

      do ii=startfrom, nfuncs_dynk
         if (cexpr_dynk(funcs_dynk(ii,1)).eq.funName) then
            dynk_findFUNindex = ii
            exit ! break loop
         endif
      end do
      
      end function

      integer function dynk_findSETindex
     &     (element_name, att_name, startfrom)
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 23-10-2014
!     Find and return the index in the sets array to the set which
!     matches element_name and att_name, which should be zero-padded.
!     Return -1 if nothing was found.
!
!     Note: It is expected that the length of element_name and att_name
!      is exactly maxstrlen_dynk .
!-----------------------------------------------------------------------
      implicit none
      character(maxstrlen_dynk) element_name, att_name
      integer startfrom
      intent(in) element_name, att_name, startfrom
      
      integer ii
      
      dynk_findSETindex = -1
      
      do ii=startfrom, nsets_dynk
         if ( csets_dynk(ii,1) .eq. element_name .and.
     &        csets_dynk(ii,2) .eq. att_name ) then
            dynk_findSETindex = ii
            exit                ! break loop
         endif
      enddo
      
      end function
      
      subroutine dynk_inputsanitycheck
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 14-10-2014
!     Check that DYNK block input in fort.3 was sane
!-----------------------------------------------------------------------
      implicit none
+ca crcoall

      integer ii, jj
      integer biggestTurn ! Used as a replacement for ending turn -1 (infinity)
      logical sane
      sane = .true.
      
      ! Check that there are no doubly-defined function names
      do ii=1, nfuncs_dynk-1
         jj = dynk_findFUNindex(cexpr_dynk(funcs_dynk(ii,1)),ii+1)
         if ( jj.ne. -1) then
            sane = .false.
            write (lout,*)
     &           "DYNK> Insane: function ", 
     &           ii, "has the same name as", jj
         end if
      end do
      
      ! Check that no SETS work on same elem/att at same time
      biggestTurn = 1
      do ii=1, nsets_dynk
         if (sets_dynk(ii,3) .gt. biggestTurn) then
            biggestTurn = sets_dynk(ii,3)
         endif
      end do
      biggestTurn = biggestTurn+1 !Make sure it is unique
      if (biggestTurn .le. 0) then
         !In case of integer overflow
         write(lout,*)
     &        "FATAL ERROR: Integer overflow in dynk_inputsanitycheck!"
         call prror(-1)
      endif
      !Do the search!
      do ii=1, nsets_dynk-1
         if (sets_dynk(ii,3).eq.-1) sets_dynk(ii,3) = biggestTurn
!         write(*,*) "DBG: ii=",ii,
!     &           csets_dynk(ii,1)," ", csets_dynk(ii,2)
!         write(*,*)"DBG:", sets_dynk(ii,2),sets_dynk(ii,3)

         jj = ii
         do while (.true.)
            !Only check SETs affecting the same elem/att
            jj = dynk_findSETindex(csets_dynk(ii,1),
     &                             csets_dynk(ii,2),jj+1)

!            write(*,*)" DBG: jj=",jj, 
!     &           csets_dynk(jj,1)," ", csets_dynk(jj,2)

            if (jj .eq. -1) exit ! next outer loop

            if (sets_dynk(jj,3).eq.-1) sets_dynk(jj,3) = biggestTurn

!            write(*,*)" DBG:", sets_dynk(jj,2),sets_dynk(jj,3)

            if ( sets_dynk(jj,2) .le. sets_dynk(ii,2) .and.
     &           sets_dynk(jj,3) .ge. sets_dynk(ii,2) ) then
               sane = .false.
               write (lout,"(A,I4,A,I8,A,I4,A,I8,A,I4,A,I8,A,I4)")
     &              " DYNK> Insane: Lower edge of SET #", jj,
     &        " =", sets_dynk(jj,2)," <= lower edge of SET #",ii,
     &        " =", sets_dynk(ii,2),"; and also higer edge of SET #",jj,
     &        " =", sets_dynk(jj,3)," >= lower edge of SET #", ii

            else if (sets_dynk(jj,3) .ge. sets_dynk(ii,3) .and.
     &               sets_dynk(jj,2) .le. sets_dynk(ii,3) ) then
               sane = .false.
               write(lout, "(A,I4,A,I8,A,I4,A,I8,A,I4,A,I8,A,I4)")
     &              " DYNK> Insane: Upper edge of SET #", jj,
     &        " =", sets_dynk(jj,3)," >= upper edge of SET #",ii,
     &        " =", sets_dynk(ii,3),"; and also lower edge of SET #",jj,
     &        " =", sets_dynk(jj,2)," <= upper edge of SET #", ii
      
            else if (sets_dynk(jj,2) .ge. sets_dynk(ii,2) .and.
     &               sets_dynk(jj,3) .le. sets_dynk(ii,3) ) then
               ! (other way round gets caugth by the first "if")
               sane = .false.
               write(lout, "(A,I4,A,I8,A,I8,A,A,I4,A,I8,A,I8,A)")
     &              " DYNK> Insane: SET #", jj,
     &        " = (", sets_dynk(jj,2),", ", sets_dynk(jj,3), ")",
     &        " is inside SET #", ii, " = (", 
     &                sets_dynk(ii,2),", ", sets_dynk(ii,3), ")"
            endif
            if (sets_dynk(jj,3).eq.biggestTurn) sets_dynk(jj,3) = -1
         enddo
         if (sets_dynk(ii,3).eq.biggestTurn) sets_dynk(ii,3) = -1
      enddo

      if (.not. sane) then
         write (lout,*) "****************************************"
         write (lout,*) "*******DYNK input was insane************"
         write (lout,*) "****************************************"
         call dynk_dumpdata
         call prror(-11)
      else if (sane .and. ldynkdebug) then
         write (lout,*)
     &        "DYNK> DYNK input was sane"
      end if
      end subroutine

      subroutine dynk_dumpdata
!----------------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 14-10-2014
!     Dump arrays with DYNK FUN and SET data to the std. output for debugging
!----------------------------------------------------------------------------
      implicit none
+ca comgetfields
+ca stringzerotrim
+ca crcoall

      integer ii
      write(lout,*)
     &     "**************** DYNK parser knows: ****************"

      write (lout,*) "OPTIONS:"
      write (lout,*) " ldynk            =", ldynk
      write (lout,*) " ldynkdebug       =", ldynkdebug
      write (lout,*) " ldynkfiledisable =", ldynkfiledisable

      write (lout,*) "FUN:"
      write (lout,*) "ifuncs: (",nfuncs_dynk,")"
      do ii=1,nfuncs_dynk
         write (lout,*) 
     &        ii, ":", funcs_dynk(ii,:)
      end do
      write (lout,*) "iexpr_dynk: (",niexpr_dynk,")"
      do ii=1,niexpr_dynk
         write (lout,*)
     &     ii, ":", iexpr_dynk(ii)
      end do
      write (lout,*) "fexpr_dynk: (",nfexpr_dynk,")"
      do ii=1,nfexpr_dynk
         write (lout, '(1x,I8,1x,A,1x,E16.9)')
     &   ii, ":", fexpr_dynk(ii)
      end do
      write (lout,*) "cexpr_dynk: (",ncexpr_dynk,")"
      do ii=1,ncexpr_dynk
         write(lout,*)
     &   ii, ":", "'"//trim(stringzerotrim(cexpr_dynk(ii)))//"'"
      end do

      write (lout,*) "SET:"      
      write (lout,*) "sets(,:) csets(,1) csets(,2): (",
     &     nsets_dynk,")"
      do ii=1,nsets_dynk
         write (lout,*)
     &        ii, ":", sets_dynk(ii,:),
     &        "'"//trim(stringzerotrim(csets_dynk(ii,1)))//
     &  "' ", "'"//trim(stringzerotrim(csets_dynk(ii,2)))//"'"
      end do
      write (lout,*) "csets_unique_dynk: (",nsets_unique_dynk,")"
      do ii=1,nsets_unique_dynk
         write(lout, '(1x,I8,1x,A,1x,E16.9)')
     &       ii, ": '"//
     &       trim(stringzerotrim(csets_unique_dynk(ii,1)))//"' '"//
     &       trim(stringzerotrim(csets_unique_dynk(ii,2)))//"' = ",
     &        fsets_origvalue_dynk(ii)
      end do

      write (lout,*) "*************************************************"
      
      end subroutine
      
      subroutine dynk_pretrack
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 21-10-2014
!     
!     Save original values for GET functions and sanity check
!     that elements/attributes for SET actually exist.
!-----------------------------------------------------------------------
      implicit none
+ca common
+ca comgetfields
+ca stringzerotrim
+ca crcoall
+ca commondl

      !Temp variables
      integer ii,jj
      character(maxstrlen_dynk) element_name_s, att_name_s
      logical found, badelem
      integer ix
      if (ldynkdebug) then
         write(lout,*)
     &    "DYNKDEBUG> In dynk_pretrack()"
      end if
      
      ! Find which elem/attr combos are affected by SET
      nsets_unique_dynk = 0 !Assuming this is only run once
      do ii=1,nsets_dynk
         if ( dynk_findSETindex(
     &        csets_dynk(ii,1),csets_dynk(ii,2), ii+1 ) .eq. -1 ) then
            ! Last SET which has this attribute, store it
            nsets_unique_dynk = nsets_unique_dynk+1

            csets_unique_dynk(nsets_unique_dynk,1) = csets_dynk(ii,1)
            csets_unique_dynk(nsets_unique_dynk,2) = csets_dynk(ii,2)
            
            ! Sanity check: Does the element actually exist?
            element_name_s =
     &           trim(stringzerotrim(
     &           csets_unique_dynk(nsets_unique_dynk,1) ))
            att_name_s     =
     &           trim(stringzerotrim(
     &           csets_unique_dynk(nsets_unique_dynk,2) ))
            found = .false.

            ! Special case: the element name GLOBAL-VARS (not a real element)
            ! can be used to redefine a global variable by some function.
            if (element_name_s .eq. "GLOBAL-VARS") then
               found=.true.
               badelem = .false.
               
               if (att_name_s .eq. "E0") then
                  if (idp.eq.0 .or. ition.eq.0) then ! 4d tracking..
                     write(lout,*) "DYNK> Insane - attribute '",
     &                  att_name_s, "' is not valid for 'GLOBAL-VARS' ",
     &                  "when doing 4d tracking"
                     call prror(-1)
                  endif
               else
                  badelem=.true.
               endif

               if (badelem) then
                  write(lout,*) "DYNK> Insane - attribute '",
     &                att_name_s, "' is not valid for 'GLOBAL-VARS'"
                  call prror(-1)
               endif
            endif
            
            do jj=1,il
               if ( bez(jj).eq. element_name_s) then
                  
                  found = .true.
                  
                  ! Check that the element type and attribute is supported
                  ! Check that the element can be used now
                  badelem = .false.
                  if (abs(kz(jj)).ge.1 .and. abs(kz(jj)).le.10) then !thin kicks
                     if (att_name_s .ne. "average_ms") then
                        badelem = .true.
                     endif
                  elseif (abs(kz(jj)).eq.12) then !cavity
                     if (.not. (att_name_s.eq."voltage"  .or.
     &                    att_name_s.eq."harmonic"       .or.
     &                    att_name_s.eq."lag_angle"          )) then
                        badelem = .true.
                     endif
                     if (kp(jj).ne.6) then
                        write(lout,*) "DYNK> Insane - want to modify ",

     &                      "DISABLED RF cavity named '",element_name_s,
     &                      ". Please make sure that the voltage and ",
     &                      "harmonic number in the SINGLE ELEMENTS ",
     &                      "block is not 0!"
                        call prror(-1)
                     endif
                     if (nvar .eq. 5) then
                        write(lout,*) "DYNK> Insane - want to modify ",
     &                       "RF cavity named '", element_name_s, "', ",
     &                       "but nvars=5 (from DIFF block)."
                     endif

                  elseif (abs(kz(jj)).eq.23 .or.   ! crab
     &                    abs(kz(jj)).eq.26 .or.   ! cc multipole,  order 2
     &                    abs(kz(jj)).eq.27 .or.   ! cc multipole,  order 3
     &                    abs(kz(jj)).eq.28 ) then ! cc muiltipole, order 4
                     if (.not. (att_name_s.eq."voltage"   .or.
     &                          att_name_s.eq."frequency" .or.
     &                          att_name_s.eq."phase"         )) then
                        badelem = .true.
                     endif
                  endif

                  ! Special case:
                  ! Should the error only occur if we actually have a GLOBAL-VARS element?
                  if (bez(jj) .eq. "GLOBAL-VARS") then
                     write(lout,*) "DYNK> Insane - element found '",
     &                    "GLOBAL-VARS' is not a valid element name, ",
     &                    "it is reserved"
                     call prror(-1) 
                  endif
                  
                  if (badelem) then
                     write(lout,*) "DYNK> Insane - attribute '",
     &                    att_name_s, "' is not valid for element '",
     &                    element_name_s, "' which is of type",kz(jj)
                     call prror(-1) 
                  endif
                  
               endif
            enddo
            if (.not. found) then
               write (lout,*) "DYNK> Insane: Element '", element_name_s,
     &                        "' was not found"
               call prror(-1)
            endif

            ! Store original value of data point
            fsets_origvalue_dynk(nsets_unique_dynk) =
     &           dynk_getvalue(csets_dynk(ii,1),csets_dynk(ii,2))
         endif
      enddo

      ! Save original values for GET functions
      do ii=1,nfuncs_dynk
         if (funcs_dynk(ii,2) .eq. 0) then !GET
            fexpr_dynk(funcs_dynk(ii,3)) =
     &           dynk_getvalue( cexpr_dynk(funcs_dynk(ii,1)+1),
     &                          cexpr_dynk(funcs_dynk(ii,1)+2) )
         endif
      enddo

      if (ldynkdebug) call dynk_dumpdata
      
      end subroutine
      
      subroutine dynk_apply(turn)
!-----------------------------------------------------------------------
!     A.Mereghetti, for the FLUKA Team
!     K.Sjobak & A. Santamaria, BE-ABP/HSS
!     last modified: 30-10-2014
!     actually apply dynamic kicks
!     always in main code
!
!     For each element (group) flagged with SET(R), compute the new value
!     using dynk_computeFUN() at the given (shifted) turn number
!     using the specified FUN function. The values are stored 
!     in the element using dynk_setvalue().
!     
!     Also resets the values at the beginning of each pass through the
!     turn loop (for COLLIMATION).
!
!     Also writes the file "dynksets.dat", only on the first turn.
!-----------------------------------------------------------------------
      implicit none

+ca crcoall
+ca parnum
+ca common
+ca commonmn
+ca commontr
+ca comgetfields
+ca stringzerotrim
+if boinc
      character*256 filename
+ei

+if collimat
+ca collpara
+ca dbcommon
+ei

!     interface variables
      integer turn  ! current turn number
      intent(in) turn

!     temporary variables
      integer ii, jj, shiftedTurn
      logical lopen
      double precision getvaldata, newValue
      
      character(maxstrlen_dynk) whichFUN(maxsets_dynk) !Which function was used to set a given elem/attr?
      integer whichSET(maxsets_dynk) !Which SET was used for a given elem/attr?

      !Temp variable for padding the strings for output to dynksets.dat
      character(20) outstring_tmp1,outstring_tmp2,outstring_tmp3
      
      if ( ldynkdebug ) then
         write (lout,*)
     &   'DYNKDEBUG> In dynk_apply(), turn = ',
+if collimat
     & turn, "samplenumber =", samplenumber
+ei
+if .not.collimat
     & turn
+ei
      end if
      
      !Initialize variables (every call)
      do jj=1, nsets_unique_dynk
         whichSET(jj) = -1
         do ii=1,maxstrlen_dynk
            whichFUN(jj)(ii:ii) = char(0)
         enddo
      enddo

      !First-turn initialization, including some parts which are specific for collimat.
      if (turn .eq. 1) then
         ! Reset RNGs and filters 
         do ii=1, nfuncs_dynk
            if (funcs_dynk(ii,2) .eq. 6) then !RANDG
               if (ldynkdebug) then
                  write (lout,*) 
     &               "DYNKDEBUG> Resetting RANDG for FUN named '",
     & trim(stringzerotrim( cexpr_dynk(funcs_dynk(ii,1)) )), "'"
               endif

               iexpr_dynk(funcs_dynk(ii,3)+3) =
     &              iexpr_dynk(funcs_dynk(ii,3) )
               iexpr_dynk(funcs_dynk(ii,3)+4) =
     &              iexpr_dynk(funcs_dynk(ii,3)+1)
               
            else if (funcs_dynk(ii,2) .eq. 7) then !RANDU
               if (ldynkdebug) then
                  write (lout,*) 
     &               "DYNKDEBUG> Resetting RANDU for FUN named '",
     & trim(stringzerotrim( cexpr_dynk(funcs_dynk(ii,1)) )), "'"
               endif

               iexpr_dynk(funcs_dynk(ii,3)+2) =
     &              iexpr_dynk(funcs_dynk(ii,3) )
               iexpr_dynk(funcs_dynk(ii,3)+3) =
     &              iexpr_dynk(funcs_dynk(ii,3)+1)

            else if (funcs_dynk(ii,2) .eq. 8) then !RANDON
               if (ldynkdebug) then
                  write (lout,*) 
     &               "DYNKDEBUG> Resetting RANDON for FUN named '",
     & trim(stringzerotrim( cexpr_dynk(funcs_dynk(ii,1)) )), "'"
               endif

               iexpr_dynk(funcs_dynk(ii,3)+2) =
     &              iexpr_dynk(funcs_dynk(ii,3) )
               iexpr_dynk(funcs_dynk(ii,3)+3) =
     &              iexpr_dynk(funcs_dynk(ii,3)+1)

            else if (funcs_dynk(ii,2) .eq. 10) then !FIR
               if (ldynkdebug) then
                  write (lout,*)
     &               "DYNKDEBUG> Resetting FIR named '",
     & trim(stringzerotrim( cexpr_dynk(funcs_dynk(ii,1)) )), "'"
               endif
               do jj=0, funcs_dynk(ii,4)
                  fexpr_dynk(funcs_dynk(ii,3)+jj*3+1) =
     &                 fexpr_dynk(funcs_dynk(ii,3)+jj*3+2)
               enddo
            else if (funcs_dynk(ii,2) .eq. 11) then !IIR
               if (ldynkdebug) then
                  write (lout,*)
     &               "DYNKDEBUG> Resetting IIR named '",
     & trim(stringzerotrim( cexpr_dynk(funcs_dynk(ii,1)) )), "'"
               endif
               do jj=0, funcs_dynk(ii,4)
                  fexpr_dynk(funcs_dynk(ii,3)+jj*6+1) =
     &                 fexpr_dynk(funcs_dynk(ii,3)+jj*6+2)
                  fexpr_dynk(funcs_dynk(ii,3)+jj*6+4) =
     &                 fexpr_dynk(funcs_dynk(ii,3)+jj*6+5)
               enddo
            endif
            
         enddo !END "do ii=1, nfuncs_dynk"

         !Open dynksets.dat
+if collimat
         if (samplenumber.eq.1) then
+ei
+if cr
         ! Could have loaded a CR just before tracking starts;
         ! In this case, the dynksets is already open and positioned,
         ! so don't try to open the file again.
         if (dynkfilepos .eq.-1) then
+ei
            inquire( unit=665, opened=lopen )
            if (lopen) then
               write(lout,*) "DYNK> **** ERROR in dynk_apply() ****"
               write(lout,*) "DYNK> unit 665 for dynksets.dat"//
     &                       " was already taken"
              call prror(-1)
            end if
+if boinc
            call boincrf("dynksets.dat",filename)
            open(unit=665, file=filename,
     &           status="replace",action="write")
+ei
+if .not.boinc
            open(unit=665, file="dynksets.dat",
     &           status="replace",action="write")
+ei

            if (ldynkfiledisable) then
               write (665,*) "### DYNK file output was disabled ",
     &                       "with flag NOFILE in fort.3 ###"
            else 
               write(665,*)
     &              "# turn element attribute SETidx funname value"
            endif
+if cr
            !Note: To be able to reposition, each line should be shorter than 255 chars
            dynkfilepos = 1
            
            ! Flush the unit
            endfile (665,iostat=ierro)
            backspace (665,iostat=ierro)
+ei
+if cr
         endif !END if(dynkfilepos.eq.-1)
+ei
+if collimat
         endif !END if(samplenumber.eq.1)
+ei
 
+if collimat
         ! Reset values to original settings in turn 1 
         if (samplenumber.gt.1) then
            if (ldynkdebug) then
               write (lout,*) "DYNKDEBUG> New collimat sample, ",
     &            "samplenumber = ", samplenumber,
     &                     "resetting the SET'ed values."
            endif
            do ii=1, nsets_unique_dynk
               newValue = fsets_origvalue_dynk(ii)
               if (ldynkdebug) then
                  write (lout,*) "DYNKDEBUG> Resetting: '",
     &         trim(stringzerotrim(csets_unique_dynk(ii,1))),
     &         "':'",trim(stringzerotrim(csets_unique_dynk(ii,2))),
     &         "', newValue=", newValue
               endif

               call dynk_setvalue(csets_unique_dynk(ii,1),
     &                            csets_unique_dynk(ii,2),
     &                            newValue )
            enddo
         endif !END "if (samplenumber.gt.1) then"
+ei !END +if collimat
      endif ! END "if (turn .eq. 1) then"
      
      !Apply the sets
      do ii=1,nsets_dynk
         ! Sanity check already confirms that only a single SET
         ! is active on a given element:attribute on a given turn.
         
         !Active in this turn?
         if (turn .ge. sets_dynk(ii,2) .and.
     &       ( turn .le. sets_dynk(ii,3) .or. 
     &         sets_dynk(ii,3) .eq. -1       ) ) then
            
            !Shifting
            shiftedTurn = turn + sets_dynk(ii,4)
            
            !Set the value
            newValue = dynk_computeFUN(sets_dynk(ii,1),shiftedTurn)
            if (ldynkdebug) then
               write (lout, '(1x,A,I5,A,I8,A,E16.9)')
     &              "DYNKDEBUG> Applying set #", ii, " on '"//
     &           trim(stringzerotrim(csets_dynk(ii,1)))//
     &           "':'"// trim(stringzerotrim(csets_dynk(ii,2)))//
     &           "', shiftedTurn=",shiftedTurn,", value=",newValue
            endif
            call dynk_setvalue(csets_dynk(ii,1),
     &                         csets_dynk(ii,2),
     &                         newValue)
     &           
            
            if (ldynkdebug) then
               getvaldata = dynk_getvalue( csets_dynk(ii,1), 
     &                                     csets_dynk(ii,2) )
               write (lout, '(1x,A,E16.9)')
     &              "DYNKDEBUG> Read back value = ", getvaldata

               if (getvaldata .ne. newValue) then
                  write(lout,*)
     &            "DYNKDEBUG> WARNING Read back value differs from set!"
               end if
            endif
            
            !For the output file: Which function was used?
            do jj=1, nsets_unique_dynk
               if (csets_dynk(ii,1) .eq. csets_unique_dynk(jj,1) .and.
     &             csets_dynk(ii,2) .eq. csets_unique_dynk(jj,2) ) then
                  whichSET(jj)=ii
                  whichFUN(jj)=cexpr_dynk(funcs_dynk(sets_dynk(ii,1),1))
               endif
            enddo
         end if
      end do
      
      !Write output file
+if collimat
      if (samplenumber.eq.1 .and..not.ldynkfiledisable) then
+ei
+if .not.collimat
      if (.not.ldynkfiledisable) then
+ei
         do jj=1,nsets_unique_dynk
            getvaldata =  dynk_getvalue( csets_unique_dynk(jj,1),
     &                                   csets_unique_dynk(jj,2) )
            
            if (whichSET(jj) .eq. -1) then
               whichFUN(jj) = "N/A"
            endif

            !For compatibility with old output, the string output to dynksets.dat should be left-adjusted within each column.
            !Previously, the csets_unique_dynk etc. strings could maximally be 20 long each.
            !Note that the length of each string is limited by the max length of element names (16), attribute names, and FUN names.
            write(outstring_tmp1,'(A20)')
     &           stringzerotrim(csets_unique_dynk(jj,1))
            outstring_tmp1(len(outstring_tmp1)+1:) = ' ' !Pad with trailing blanks
            write(outstring_tmp2,'(A20)')
     &           stringzerotrim(csets_unique_dynk(jj,2))
            outstring_tmp2(len(outstring_tmp2)+1:) = ' '
            write(outstring_tmp3,'(A20)')
     &           stringzerotrim(whichFUN(jj))
            outstring_tmp3(len(outstring_tmp3)+1:) = ' '
            
            write(665,'(I12,1x,A20,1x,A20,1x,I4,1x,A20,E16.9)')
     &           turn, 
     &           outstring_tmp1,
     &           outstring_tmp2,
     &           whichSET(jj),
     &           outstring_tmp3,
     &           getvaldata
         enddo
         
+if cr
         !Note: To be able to reposition, each line should be shorter than 255 chars
         dynkfilepos = dynkfilepos+nsets_unique_dynk
+ei
         !Flush the unit
         endfile (665,iostat=ierro)
         backspace (665,iostat=ierro)

      endif

      end subroutine
!
      
      recursive double precision function 
     &     dynk_computeFUN( funNum, turn ) result(retval)
!-----------------------------------------------------------------------
!     K. Sjobak, BE-ABP/HSS
!     last modified: 17-10-2014
!     Compute the value of a given DYNK function (funNum) for the given turn
!-----------------------------------------------------------------------
      implicit none
+ca comgetfields
+ca stringzerotrim

      integer funNum, turn
      intent (in) funNum, turn
      
      !Functions to call
+if crlibm
      double precision round_near
+ei

+if crlibm
+ca crlibco
+ei

+ca crcoall
      
      ! Temporaries for FILELIN
      integer filelin_start, filelin_xypoints
      
      ! Temporaries for random generator functions
      integer tmpseed1, tmpseed2
      double precision ranecu_rvec(1)
      
      ! General temporaries
      integer foff !base offset into fexpr array
      integer ii,jj!Loop variable

+if crlibm
      !String handling tempraries for PIPE, preformatting for round_near
      integer errno !for round_near
      integer nchars
      parameter (nchars=160)
      character*(nchars) ch
+ei

! Usefull constants (pi and two)
+ca common
+ca parnum

      if (funNum .lt. 1 .or. funNum .gt. nfuncs_dynk) then
         write(lout,*) "DYNK> **** ERROR in dynk_computeFUN() ****"
         write(lout,*) "DYNK> funNum =", funNum
         write(lout,*) "DYNK> Invalid funNum, nfuncs_dynk=", nfuncs_dynk
         call dynk_dumpdata
         call prror(-1)
      endif
      
      select case ( funcs_dynk(funNum,2) )                              ! WHICH FUNCTION TYPE?
      case (0)                                                          ! GET
         retval = fexpr_dynk(funcs_dynk(funNum,3))
      case (1)                                                          ! FILE
         if (turn .gt. funcs_dynk(funNum,5) ) then
            write(lout,*)"DYNK> ****ERROR in dynk_computeFUN():FILE****"
            write(lout,*)"DYNK> funNum =", funNum, "turn=", turn
            write(lout,*)"DYNK> Turn > length of file = ", 
     &           funcs_dynk(funNum,5)
            call dynk_dumpdata
            call prror(-1)
         elseif (turn .lt. 1) then
            write(lout,*)"DYNK> ****ERROR in dynk_computeFUN():FILE****"
            write(lout,*)"DYNK> funNum =", funNum, "turn=", turn
            write(lout,*)"DYNK> Turn < 1, check your turn-shift!"
            call dynk_dumpdata
            call prror(-1)
         endif

         retval = fexpr_dynk(funcs_dynk(funNum,4)+turn-1)
      case(2)                                                           ! FILELIN
         filelin_start    = funcs_dynk(funNum,4)
         filelin_xypoints = funcs_dynk(funNum,5)
         !Pass the correct array views/sections to dynk_lininterp
         retval = dynk_lininterp( dble(turn),
     &       fexpr_dynk(filelin_start:filelin_start+filelin_xypoints-1),
     &       fexpr_dynk(filelin_start +  filelin_xypoints:
     &                  filelin_start +2*filelin_xypoints-1),
     &        filelin_xypoints )
      case(3)                                                           ! PIPE
         write(iexpr_dynk(funcs_dynk(funNum,3))+1,"(a,i7)") 
     &        "GET ID="//
     &        trim(stringzerotrim(
     &        cexpr_dynk(funcs_dynk(funNum,1)+3)
     &        ))//" TURN=",turn
+if .not.crlibm
         read(iexpr_dynk(funcs_dynk(funNum,3)),*) retval
+ei
+if crlibm
         read(iexpr_dynk(funcs_dynk(funNum,3)),"(a)") ch
         call getfields_split( ch, getfields_fields, getfields_lfields,
     &                             getfields_nfields, getfields_lerr )
         if ( getfields_lerr ) then
            write(lout,*)"DYNK> ****ERROR in dynk_computeFUN():PIPE****"
            write(lout,*)"DYNK> getfields_lerr=", getfields_lerr
            call prror(-1)
         endif
         if (getfields_nfields .ne. 1) then
            write(lout,*)"DYNK> ****ERROR in dynk_computeFUN():PIPE****"
            write(lout,*)"DYNK> getfields_nfields=", getfields_nfields
            write(lout,*)"DYNK> Expected a single number."
            call prror(-1)
         endif
         retval = round_near(errno,
     &        getfields_lfields(1)+1, getfields_fields(1) )
         if (errno.ne.0)
     &        call rounderr( errno,getfields_fields,1,retval )
+ei
         
      case (6)                                                          ! RANDG
         ! Save old seeds and load our current seeds
         call recuut(tmpseed1,tmpseed2)
         call recuin(iexpr_dynk(funcs_dynk(funNum,3)+3),
     &               iexpr_dynk(funcs_dynk(funNum,3)+4) )
         ! Run generator for 1 value with current mcut
         call ranecu( ranecu_rvec, 1,
     &                iexpr_dynk(funcs_dynk(funNum,3)+2) )
         ! Save our current seeds and load old seeds
         call recuut(iexpr_dynk(funcs_dynk(funNum,3)+3),
     &               iexpr_dynk(funcs_dynk(funNum,3)+4) )
         call recuin(tmpseed1,tmpseed2)
         ! Change to mu, sigma
         retval = fexpr_dynk(funcs_dynk(funNum,4))
     &          + fexpr_dynk(funcs_dynk(funNum,4)+1)*ranecu_rvec(1)

      case (7)                                                          ! RANDU
         ! Save old seeds and load our current seeds
         call recuut(tmpseed1,tmpseed2)
         call recuin(iexpr_dynk(funcs_dynk(funNum,3)+2),
     &               iexpr_dynk(funcs_dynk(funNum,3)+3) )
         ! Run generator for 1 value with mcut=-1
         call ranecu( ranecu_rvec, 1, -1 )
         ! Save our current seeds and load old seeds
         call recuut(iexpr_dynk(funcs_dynk(funNum,3)+2),
     &               iexpr_dynk(funcs_dynk(funNum,3)+3) )
         call recuin(tmpseed1,tmpseed2)
         retval = ranecu_rvec(1)

      case (8)                                                         ! RANDON
        ! Save old seeds and load our current seeds
         call recuut(tmpseed1,tmpseed2)
         call recuin(iexpr_dynk(funcs_dynk(funNum,3)+2),
     &               iexpr_dynk(funcs_dynk(funNum,3)+3) )
         ! Run generator for 1 value with mcut=-1
         call ranecu( ranecu_rvec, 1, -1 )
         ! Save our current seeds and load old seeds
         call recuut(iexpr_dynk(funcs_dynk(funNum,3)+2),
     &               iexpr_dynk(funcs_dynk(funNum,3)+3) )
         call recuin(tmpseed1,tmpseed2)
	! routine for switching element (orginially the electron lens) ON or OFF
        ! when random value is less than P, set ON, else OFF 
         if (ranecu_rvec(1) .lt. fexpr_dynk(funcs_dynk(funNum,4))) then 
            retval = 1.0
         else 
            retval = 0.0
         endif

      case(10)                                                          ! FIR
         foff = funcs_dynk(funNum,3)
         !Shift storage 1 back
         do ii=funcs_dynk(funNum,4)-1,0,-1
            jj = ii*3
            fexpr_dynk(foff+jj+4) = fexpr_dynk(foff+jj+1)
         enddo
         !Evaluate the next input function
         fexpr_dynk(foff+1) = dynk_computeFUN(funcs_dynk(funNum,5),turn)
         !Compute the filtered value
         retval = 0.0
         do ii=0,funcs_dynk(funNum,4)
            jj = ii*3
            retval = retval + 
     &           fexpr_dynk(foff+jj)*fexpr_dynk(foff+jj+1)
         enddo
      case(11)                                                          ! IIR
         foff = funcs_dynk(funNum,3)
         !Shift storage 1 back
         do ii=funcs_dynk(funNum,4)-1,0,-1
            jj = ii*6
            fexpr_dynk(foff+jj+7) = fexpr_dynk(foff+jj+1)
            fexpr_dynk(foff+jj+10) = fexpr_dynk(foff+jj+4)
         enddo
         !Evaluate the next input function
         fexpr_dynk(foff+1) = dynk_computeFUN(funcs_dynk(funNum,5),turn)
         fexpr_dynk(foff+4) = 0.0
         !Compute the filtered value
         retval = 0.0
         do ii=0,funcs_dynk(funNum,4)
            jj = ii*6
            retval = retval +
     &           fexpr_dynk(foff+jj  ) * fexpr_dynk(foff+jj+1) +
     &           fexpr_dynk(foff+jj+3) * fexpr_dynk(foff+jj+4)
         enddo
         !To be shifted at the next evaluation
         fexpr_dynk(foff+4) = retval
         
      case (20)                                                         ! ADD
         retval = dynk_computeFUN(funcs_dynk(funNum,3),turn)
     &          + dynk_computeFUN(funcs_dynk(funNum,4),turn)
      case (21)                                                         ! SUB
         retval = dynk_computeFUN(funcs_dynk(funNum,3),turn)
     &          - dynk_computeFUN(funcs_dynk(funNum,4),turn)
      case (22)                                                         ! MUL
         retval = dynk_computeFUN(funcs_dynk(funNum,3),turn)
     &          * dynk_computeFUN(funcs_dynk(funNum,4),turn)
      case (23)                                                         ! DIV
         retval = dynk_computeFUN(funcs_dynk(funNum,3),turn)
     &          / dynk_computeFUN(funcs_dynk(funNum,4),turn)
      case (24)                                                         ! POW
         retval = dynk_computeFUN(funcs_dynk(funNum,3),turn)
     &         ** dynk_computeFUN(funcs_dynk(funNum,4),turn)
         
      case (30)                                                         ! MINUS
         retval = (-1)*dynk_computeFUN(funcs_dynk(funNum,3),turn)
      case (31)                                                         ! SQRT
C+if crlibm
C      retval = sqrt_rn(dynk_computeFUN(funcs_dynk(funNum,3),turn))
C+ei
C+if .not.crlibm      
      retval = sqrt(dynk_computeFUN(funcs_dynk(funNum,3),turn))
C+ei
      case (32)                                                         ! SIN
+if crlibm
         retval = sin_rn(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
+if .not.crlibm
         retval = sin(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
      case (33)                                                         ! COS
+if crlibm
         retval = cos_rn(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
+if .not.crlibm
         retval = cos(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
      case (34)                                                         ! LOG
+if crlibm
         retval = log_rn(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
+if .not.crlibm
         retval = log(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
      case (35)                                                         ! LOG10
+if crlibm
         retval = log10_rn(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
+if .not.crlibm
         retval = log10(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
      case (36)                                                         ! EXP
+if crlibm
         retval = exp_rn(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
+if .not.crlibm
         retval = exp(dynk_computeFUN(funcs_dynk(funNum,3),turn))
+ei
      
      case (40)                                                         ! CONST
         retval = fexpr_dynk(funcs_dynk(funNum,3))
      case (41)                                                         ! TURN
         retval = turn
      case (42)                                                         ! LIN
         retval = turn*fexpr_dynk(funcs_dynk(funNum,3)) + 
     &                 fexpr_dynk(funcs_dynk(funNum,3)+1)
      case (43)                                                         ! LINSEG
         filelin_start    = funcs_dynk(funNum,3)
         filelin_xypoints = 2
         !Pass the correct array views/sections to dynk_lininterp
         retval = dynk_lininterp( dble(turn),
     &       fexpr_dynk(filelin_start:filelin_start+1),
     &       fexpr_dynk(filelin_start+2:filelin_xypoints+3),
     &       filelin_xypoints )
      case (44,45)                                                      ! QUAD/QUADSEG
         retval = (turn**2)*fexpr_dynk(funcs_dynk(funNum,3))   + (
     &                 turn*fexpr_dynk(funcs_dynk(funNum,3)+1) +
     &                      fexpr_dynk(funcs_dynk(funNum,3)+2) )

      case (60)                                                         ! SINF
+if crlibm
      retval = fexpr_dynk(funcs_dynk(funNum,3))
     &     * SIN_RN( fexpr_dynk(funcs_dynk(funNum,3)+1) * turn 
     &             + fexpr_dynk(funcs_dynk(funNum,3)+2) )

+ei
+if .not.crlibm
      retval = fexpr_dynk(funcs_dynk(funNum,3))
     &     * SIN( fexpr_dynk(funcs_dynk(funNum,3)+1) * turn 
     &          + fexpr_dynk(funcs_dynk(funNum,3)+2) )
+ei
      case (61)                                                         ! COSF
+if crlibm
      retval = fexpr_dynk(funcs_dynk(funNum,3))
     &     * COS_RN( fexpr_dynk(funcs_dynk(funNum,3)+1) * turn 
     &             + fexpr_dynk(funcs_dynk(funNum,3)+2) )

+ei
+if .not.crlibm
      retval = fexpr_dynk(funcs_dynk(funNum,3))
     &     * COS( fexpr_dynk(funcs_dynk(funNum,3)+1) * turn 
     &          + fexpr_dynk(funcs_dynk(funNum,3)+2) )
+ei
      case (62)                                                         ! COSF_RIPP
+if crlibm
      retval = fexpr_dynk(funcs_dynk(funNum,3))
     & *COS_RN( (two*pi)*dble(turn-1)/fexpr_dynk(funcs_dynk(funNum,3)+1)
     &             + fexpr_dynk(funcs_dynk(funNum,3)+2) )
+ei
+if .not.crlibm
      retval = fexpr_dynk(funcs_dynk(funNum,3))
     & *COS   ( (two*pi)*dble(turn-1)/fexpr_dynk(funcs_dynk(funNum,3)+1)
     &             + fexpr_dynk(funcs_dynk(funNum,3)+2) )
+ei
      
      case (80)                                                         ! PELP
         foff = funcs_dynk(funNum,3)
         if (turn .le. fexpr_dynk(foff)) then ! <= tinj
            ! Constant Iinj
            retval = fexpr_dynk(foff+5)
         elseif (turn .le. fexpr_dynk(foff+1)) then ! <= te
            ! Parabola (accelerate)
            retval = ( fexpr_dynk(foff+6) *
     &                 (turn-fexpr_dynk(foff))**2 ) / 2.0
     &             + fexpr_dynk(foff+5)
         elseif (turn .le. fexpr_dynk(foff+2)) then ! <= t1
            ! Exponential
            retval = fexpr_dynk(foff+7) *
     &          exp( fexpr_dynk(foff+8)*turn )
         elseif (turn .le. fexpr_dynk(foff+3)) then ! <= td
            ! Linear (max ramp rate)
            retval = fexpr_dynk(foff+10) *
     &               (turn-fexpr_dynk(foff+2))
     &             + fexpr_dynk(foff+9)
         elseif (turn .le. fexpr_dynk(foff+4)) then ! <= tnom
            ! Parabola (decelerate)
            retval =  - ( (fexpr_dynk(foff+11) *
     &                    (fexpr_dynk(foff+4)-turn)**2) ) / 2.0
     &                + fexpr_dynk(foff+12)
         else ! > tnom
            ! Constant Inom
            retval = fexpr_dynk(foff+12)
         endif

      case (81)                                                         ! ONOFF
         ii=mod(turn-1,funcs_dynk(funNum,4))
         if (ii .lt. funcs_dynk(funNum,3)) then
            retval = 1.0
         else
            retval = 0.0
         endif
         
      case default
         write(lout,*) "DYNK> **** ERROR in dynk_computeFUN(): ****"
         write(lout,*) "DYNK> funNum =", funNum, "turn=", turn
         write(lout,*) "DYNK> Unknown function type ",
     &        funcs_dynk(funNum,2)
         call dynk_dumpdata
         call prror(-1)
      end select

      end function
      
      subroutine dynk_setvalue(element_name, att_name, newValue)
!-----------------------------------------------------------------------
!     A.Santamaria & K.Sjobak, BE-ABP/HSS
!     last modified: 31-10-2014
!     Set the value of the element's attribute
!-----------------------------------------------------------------------
      use scatter, only : scatter_ELEM_scale, scatter_elemPointer
      implicit none

+ca parnum
+ca common
+ca commonmn
+ca commonm1
+ca commontr
+ca comgetfields
+ca stringzerotrim
+ca elensparam
+ca crcoall
      
      character(maxstrlen_dynk) element_name, att_name
      double precision newValue
      intent (in) element_name, att_name, newValue
      !Functions
      ! temp variables
      integer el_type, ii, j
      character(maxstrlen_dynk) element_name_stripped
      character(maxstrlen_dynk) att_name_stripped
      ! For sanity check
      logical ldoubleElement
      ldoubleElement = .false.
      
      element_name_stripped = trim(stringzerotrim(element_name))
      att_name_stripped = trim(stringzerotrim(att_name))

      if ( ldynkdebug ) then
         write (lout, '(1x,A,E16.9)')
     &        "DYNKDEBUG> In dynk_setvalue(), element_name = '"//
     &        trim(element_name_stripped)//"', att_name = '"//
     &        trim(att_name_stripped)//"', newValue =", newValue
      endif
      
C     Here comes the logic for setting the value of the attribute for all instances of the element...

      ! Special non-physical elements
      if (element_name_stripped .eq. "GLOBAL-VARS") then
         if (att_name_stripped .eq. "E0" ) then
            ! Modify the reference particle
            e0 = newValue
            e0f = sqrt(e0**2 - pma**2)
            gammar = pma/e0
            ! Modify the Energy
            do j = 1, napx
              dpsv(j) = (ejfv(j) - e0f)/e0f
              dpsv1(j) = (dpsv(j)*c1e3)/(one + dpsv(j))
              dpd(j) = one + dpsv(j)
              dpsq(j) = sqrt(dpd(j))
              oidpsv(j) = one/(one + dpsv(j))
              rvv(j) = (ejv(j)*e0f)/(e0*ejfv(j))
            enddo
         endif
         ldoubleElement = .true.
      endif
      
      ! Normal SINGLE ELEMENTs
      do ii=1,il
         ! TODO: Here one could find the right ii in dynk_pretrack,
         ! and then avoid this loop / string-comparison
         if (element_name_stripped.eq.bez(ii)) then ! name found
            el_type=kz(ii)      ! type found
            
            if (ldoubleElement) then ! Sanity check
               write(lout,*)
     &            "DYNK> ERROR: two elements with the same BEZ?"
               call prror(-1)
            end if
            ldoubleElement = .true.
          
            if ((abs(el_type).eq.1).or. ! horizontal bending kick
     &          (abs(el_type).eq.2).or. ! quadrupole kick
     &          (abs(el_type).eq.3).or. ! sextupole kick
     &          (abs(el_type).eq.4).or. ! octupole kick
     &          (abs(el_type).eq.5).or. ! decapole kick
     &          (abs(el_type).eq.6).or. ! dodecapole kick
     &          (abs(el_type).eq.7).or. ! 14th pole kick
     &          (abs(el_type).eq.8).or. ! 16th pole kick
     &          (abs(el_type).eq.9).or. ! 18th pole kick
     &          (abs(el_type).eq.10)) then ! 20th pole kick
               
               if (att_name_stripped.eq."average_ms") then !
                  ed(ii) = newValue
               else
                  goto 100 !ERROR
               endif
               call initialize_element(ii, .false.)
               
          !Not yet supported
c$$$            elseif (abs(el_type).eq.11) then !MULTIPOLES
c$$$               if (att_name_stripped.eq."bending_str") then
c$$$                  ed(ii) = newValue
c$$$               else
c$$$                  goto 100 !ERROR
c$$$               endif
c$$$               call initialize_element(ii, .false.)


          elseif (abs(el_type).eq.12) then ! cavities 
            if (att_name_stripped.eq."voltage") then ! [MV]
               ed(ii) = newValue
            elseif (att_name_stripped.eq."harmonic") then !
               ek(ii) = newValue
               el(ii) = dynk_elemdata(ii,3) !Need to reset el before calling initialize_element()
               call initialize_element(ii, .false.)
            elseif (att_name_stripped.eq."lag_angle") then ! [deg]
               el(ii) = newValue
               ! Note: el is set to 0 in initialize_element and in daten.
               !  Calling initialize element on a cavity without setting el
               !  will set phasc = 0!
               call initialize_element(ii, .false.)
            else
               goto 100 !ERROR
            endif
            
          !Not yet supported
c$$$          elseif (abs(el_type).eq.16) then ! AC dipole 
c$$$            if (att_name_stripped.eq."amplitude") then ! [T.m]
c$$$               ed(ii) = dynk_computeFUN(funNum,turn)
c$$$            elseif (att_name_stripped.eq."frequency") then ! [2pi]
c$$$               ek(ii) = dynk_computeFUN(funNum,turn)
c$$$            elseif (att_name_stripped.eq."phase") then ! [rad]
c$$$               el(ii) = dynk_computeFUN(funNum,turn)
c$$$            else
c$$$               goto 100 !ERROR
c$$$            endif

          !Not yet supported
c$$$          elseif (abs(el_type).eq.20) then ! beam-beam separation
c$$$            if (att_name_stripped.eq."horizontal") then ! [mm]
c$$$               ed(ii) = dynk_computeFUN(funNum,turn)
c$$$            elseif (att_name_stripped.eq."vertical") then ! [mm]
c$$$               ek(ii) = dynk_computeFUN(funNum,turn)
c$$$            elseif (att_name_stripped.eq."strength") then ! [m]
c$$$               el(ii) = dynk_computeFUN(funNum,turn)
c$$$            else
c$$$               goto 100 !ERROR
c$$$            endif
            
            elseif ((abs(el_type).eq.23).or.    ! crab cavity
     &              (abs(el_type).eq.26).or.    ! cc mult. kick order 2
     &              (abs(el_type).eq.27).or.    ! cc mult. kick order 3
     &              (abs(el_type).eq.28)) then  ! cc mult. kick order 4
               if (att_name_stripped.eq."voltage") then ![MV]
                  ed(ii) = newValue
               elseif (att_name_stripped.eq."frequency") then ![MHz]
                  ek(ii) = newValue
               elseif (att_name_stripped.eq."phase") then ![rad]
                  el(ii) = newValue ! Note: el is set to 0 in initialize_element and in daten.
                                    ! Calling initialize element on a crab without setting el
                                    ! will set crabph = 0!
                  call initialize_element(ii, .false.)
               else
                  goto 100 !ERROR
               endif
               
            elseif (el_type.eq.29) then          ! Electron lens
               if (att_name_stripped.eq."thetamax") then ![mrad]
                  elens_theta_max(ii) = newValue
               else
                  goto 100 !ERROR
               endif

            elseif (el_type.eq.40) then          ! Scatter
               if(att_name_stripped.eq."scaling") then
                  scatter_ELEM_scale(scatter_elemPointer(ii)) = newValue
               else
                  goto 100 !ERROR
               endif
               
            else
               WRITE (lout,*) "DYNK> *** ERROR in dynk_setvalue() ***"
               write (lout,*) "DYNK> Unsupported element type", el_type
               write (lout,*) "DYNK> element name = '",
     &              element_name_stripped,"'"
               call prror(-1)
            endif
         endif
      enddo
      
      !Sanity check
      if (.not.ldoubleElement) then
         goto 101
      endif

      return
      
      !Error handlers
 100  continue
      WRITE (lout,*)"DYNK> *** ERROR in dynk_setvalue() ***"
      WRITE (lout,*)"DYNK> Attribute'", att_name_stripped,
     &     "' does not exist for type =", el_type
      call prror(-1)

 101  continue
      WRITE (lout,*)"DYNK> *** ERROR in dynk_setvalue() ***"
      WRITE (lout,*)"DYNK> The element named '",element_name_stripped,
     &     "' was not found."
      call prror(-1)
      
      end subroutine

      double precision function dynk_getvalue (element_name, att_name)
!-----------------------------------------------------------------------
!     A.Santamaria & K. Sjobak, BE-ABP/HSS
!     last modified: 2101-2015
!
!     Returns the original value currently set by an element.
!     
!     Note: Expects that arguments element_name and att_name are
!     zero-terminated strings of length maxstrlen_dynk!
!-----------------------------------------------------------------------
      use scatter, only : scatter_ELEM_scale, scatter_elemPointer
      implicit none
+ca parnum
+ca common
+ca commonmn
+ca commontr
+ca comgetfields
+ca stringzerotrim

+ca elensparam
+ca crcoall
      
      character(maxstrlen_dynk) element_name, att_name
      intent(in) element_name, att_name
      
      integer el_type, ii
      character(maxstrlen_dynk) element_name_s, att_name_s
      
      logical ldoubleElement
      ldoubleElement = .false.  ! For sanity check
      
      element_name_s = trim(stringzerotrim(element_name))
      att_name_s = trim(stringzerotrim(att_name))
      
      if (ldynkdebug) then
         write(lout,*)
     &   "DYNKDEBUG> In dynk_getvalue(), element_name = '"//
     &    trim(element_name_s)//"', att_name = '"//trim(att_name_s)//"'"
      end if

      ! Special non-physical elements
      if (element_name_s .eq. "GLOBAL-VARS") then
         if (att_name_s .eq. "E0" ) then
            ! Return the energy
            dynk_getvalue = e0
         endif
         ldoubleElement = .true.
      endif
      
      ! Normal SINGLE ELEMENTs
      do ii=1,il
         ! TODO: Here one could find the right ii in dynk_pretrack,
         ! and then avoid this loop / string-comparison
         if (element_name_s.eq.bez(ii)) then ! name found
            el_type=kz(ii)
            if (ldoubleElement) then
               write (lout,*)
     &              "DYNK> ERROR: two elements with the same BEZ"
               call prror(-1)
            end if
            ldoubleElement = .true.
            
            ! Nonlinear elements
            if ((abs(el_type).eq.1).or.
     &          (abs(el_type).eq.2).or.
     &          (abs(el_type).eq.3).or.
     &          (abs(el_type).eq.4).or.
     &          (abs(el_type).eq.5).or.
     &          (abs(el_type).eq.6).or.
     &          (abs(el_type).eq.7).or.
     &          (abs(el_type).eq.8).or.
     &          (abs(el_type).eq.9).or.
     &          (abs(el_type).eq.10)) then
               if (att_name_s.eq."average_ms") then
                  dynk_getvalue = ed(ii)
               else
                  goto 100 !ERROR
               endif
               
c$$$            !Multipoles (Not yet supported)
c$$$            elseif (abs(el_type).eq.11) then
c$$$               if (att_name_s.eq."bending_str") then 
c$$$                  dynk_getvalue = dynk_elemdata(ii,2)
c$$$               elseif (att_name_s.eq."radius") then
c$$$                  dynk_getvalue = dynk_elemdata(ii,3)
c$$$               else
c$$$                  goto 100 !ERROR
c$$$               endif
               

            elseif (abs(el_type).eq.12) then ! cavities
               if     (att_name_s.eq."voltage"  ) then ! MV
                  dynk_getvalue = ed(ii)
               elseif (att_name_s.eq."harmonic" ) then ! harmonic number
                  dynk_getvalue = ek(ii)
               elseif (att_name_s.eq."lag_angle") then ! [deg]
                  dynk_getvalue = dynk_elemdata(ii,3)
               else
                  goto 100 !ERROR
               endif
             
            !Not yet supported
c$$$            elseif (abs(el_type).eq.16) then ! AC dipole 
c$$$               if (att_name_s.eq."amplitude") then ! [T.m]
c$$$                  nretdata = nretdata+1
c$$$                  retdata(nretdata) = ed(ii)                
c$$$               elseif (att_name_s.eq."frequency") then !  [2pi]
c$$$                  nretdata = nretdata+1
c$$$                  retdata(nretdata) = ek(ii)                
c$$$               elseif (att_name_s.eq."phase") then !  [rad]
c$$$                  nretdata = nretdata+1
c$$$                  retdata(nretdata) = el(ii)      
c$$$               else
c$$$                  goto 100 !ERROR
c$$$               endif
               
            !Not yet supported
c$$$            elseif (abs(el_type).eq.20) then ! beam-beam separation
c$$$               if (att_name_s.eq."horizontal") then ! [mm]
c$$$                  nretdata = nretdata+1
c$$$                  retdata(nretdata) = ed(ii)                
c$$$               elseif (att_name_s.eq."vertical") then ! [mm]
c$$$                  nretdata = nretdata+1
c$$$                  retdata(nretdata) = ek(ii)                
c$$$               elseif (att_name_s.eq."strength") then ! [m]
c$$$                  nretdata = nretdata+1
c$$$                  retdata(nretdata) = el(ii)       
c$$$               else
c$$$                  goto 100 !ERROR
c$$$               endif
               
            elseif ((abs(el_type).eq.23).or. ! crab cavity
     &              (abs(el_type).eq.26).or. ! cc mult. kick order 2
     &              (abs(el_type).eq.27).or. ! cc mult. kick order 3
     &              (abs(el_type).eq.28)) then ! cc mult. kick order 4
               if (att_name_s.eq."voltage") then ![MV]
                  dynk_getvalue = ed(ii)
               elseif (att_name_s.eq."frequency") then ![MHz]
                  dynk_getvalue = ek(ii)
               elseif (att_name_s.eq."phase") then ![rad]
                  if (abs(el_type).eq.23) then
                     dynk_getvalue = crabph(ii)
                  elseif (abs(el_type).eq.26) then
                     dynk_getvalue = crabph2(ii)
                  elseif (abs(el_type).eq.27) then
                     dynk_getvalue = crabph3(ii)
                  elseif (abs(el_type).eq.28) then
                     dynk_getvalue = crabph4(ii)
                  endif
               else
                  goto 100 !ERROR
               endif
               
            elseif (el_type.eq.29) then     ! Electron lens
               if(att_name_s.eq."thetamax") then ! [mrad]
                  dynk_getvalue = elens_theta_max(ii)
               else
                  goto 100 !ERROR
               endif

            elseif (el_type.eq.40) then ! Scatter
               if(att_name_s.eq."scaling") then
                  dynk_getvalue =
     &                 scatter_ELEM_scale(scatter_elemPointer(ii))
               else
                  goto 100 !ERROR
               endif
               
            endif !el_type
         endif !bez
      enddo
      
      if (ldynkdebug) then
         write(lout,*)
     &   "DYNKDEBUG> In dynk_getvalue(), returning =", dynk_getvalue
      end if

      return
      
      !Error handlers
 100  continue
      write(lout,*) "DYNK> *** ERROR in dynk_getvalue() ***"
      write(lout,*) "DYNK> Unknown attribute '", trim(att_name_s),"'",
     &     " for type",el_type," name '", trim(bez(ii)), "'"

      call prror(-1)
  
      end function
      
      double precision function dynk_lininterp(x,xvals,yvals,datalen)
      implicit none
!-----------------------------------------------------------------------
!
!     A.Mereghetti, for the FLUKA Team and K.Sjobak for BE-ABP/HSS
!     last modified: 29-10-2014
!     
!     Define a linear function with a set of x,y-coordinates xvals, yvals
!     Return this function evaluated at the point x.
!     The length of the arrays xvals and yvals should be given in datalen.
!
!     xvals should be in increasing order, if not then program is aborted.
!     If x < min(xvals) or x>max(xvals), program is aborted.
!     If datalen <= 0, program is aborted. 
!     
!-----------------------------------------------------------------------

+ca crcoall

      double precision x, xvals(*),yvals(*)
      integer datalen
      intent(in) x,xvals,yvals,datalen
      
      integer ii
      double precision dydx, y0
      
      !Sanity checks
      if (datalen .le. 0) then
         write(lout,*) "DYNK> **** ERROR in dynk_lininterp() ****"
         write(lout,*) "DYNK> datalen was 0!"

         call prror(-1)
      endif
      if ( x .lt. xvals(1) .or. x .gt. xvals(datalen) ) then
         write(lout,*) "DYNK> **** ERROR in dynk_lininterp() ****"
         write(lout,*) "x =",x, "outside range", xvals(1),xvals(datalen)
         call prror(-1)
      endif

      !Find the right indexes i1 and i2
      ! Special case: first value at first point
      if (x .eq. xvals(1)) then
         dynk_lininterp = yvals(1)
         return
      endif
      
      do ii=1, datalen-1
         if (xvals(ii) .ge. xvals(ii+1)) then
            write (lout,*) "DYNK> **** ERROR in dynk_lininterp() ****"
            write (lout,*) "DYNK> xvals should be in increasing order"
            write (lout,*) "DYNK> xvals =", xvals(:datalen)
            call prror(-1)
         endif
         
         if (x .le. xvals(ii+1)) then
            ! we're in the right interval
            dydx = (yvals(ii+1)-yvals(ii)) / (xvals(ii+1)-xvals(ii))
            y0   = yvals(ii) - dydx*xvals(ii)
            dynk_lininterp = dydx*x + y0
            return
         endif
      enddo
      
      !We didn't return yet: Something wrong
      write (lout,*) "DYNK> ****ERROR in dynk_lininterp() ****"
      write (lout,*) "DYNK> Reached the end of the function"
      write (lout,*) "DYNK> This should not happen, "//
     &               "please contact developers"
      call prror(-1)

      end function

      logical function dynk_isused(i)
!
!-----------------------------------------------------------------------
!     K. Sjobak, ABP-HSS, 23-01-2015
!     Indicates whether a structure element is in use by DYNK
!-----------------------------------------------------------------------
      
      implicit none

+ca common
+ca comgetfields
+ca stringzerotrim
+ca crcoall

      integer, intent(in) :: i
      integer ix,k
      character(maxstrlen_dynk) element_name_stripped

      !Sanity check
      if (i .gt. iu .or. i .le. 0) then
         write (lout,*)
     &        "Error in dynk_isused(): i=",i,"out of range"
         call prror(-1)
      endif
      ix = ic(i)-nblo
      if (i .le. 0) then
         write (lout,*)
     &        "Error in dynk_isused(): ix-nblo=",ix,"is a block?"
         call prror(-1)
      endif
      
      do k=1,nsets_dynk
         element_name_stripped =
     &        trim(stringzerotrim(csets_dynk(k,1)))
         if (bez(ix) .eq. element_name_stripped) then
            dynk_isused = .true.
            if (ldynkdebug)
     &         write(lout,*)
     &         "DYNKDEBUG> dynk_isused = TRUE, bez='"//bez(ix)//
     &         "', element_name_stripped='"//element_name_stripped//"'"
            return
         endif
      end do
      
      if (ldynkdebug) then
         write(lout,*)
     &      "DYNKDEBUG> dynk_isused = FALSE, bez='"//bez(ix)//"'"
      endif

      dynk_isused = .false.
      return
      
      end function

      end module dynk