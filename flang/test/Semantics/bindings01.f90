! RUN: %python %S/test_errors.py %s %flang_fc1 -pedantic
! Confirm enforcement of constraints and restrictions in 7.5.7.3
! and C733, C734 and C779, C780, C782, C783, C784, and C785.

module m
  !ERROR: An ABSTRACT derived type must be extensible
  !PORTABILITY: A derived type with the BIND attribute should not be empty [-Wempty-bind-c-derived-type]
  type, abstract, bind(c) :: badAbstract1
  end type
  !ERROR: An ABSTRACT derived type must be extensible
  type, abstract :: badAbstract2
    sequence
    real :: badAbstract2Field
  end type
  type, abstract :: abstract
   contains
    !ERROR: DEFERRED is required when an interface-name is provided
    procedure(s1), pass :: ab1
    !ERROR: Type-bound procedure 'ab3' may not be both DEFERRED and NON_OVERRIDABLE
    procedure(s1), deferred, non_overridable :: ab3
    !ERROR: DEFERRED is only allowed when an interface-name is provided
    procedure, deferred, non_overridable :: ab4 => s1
  end type
  type :: nonoverride
   contains
    procedure, non_overridable, nopass :: no1 => s1
  end type
  type, extends(nonoverride) :: nonoverride2
  end type
  type, extends(nonoverride2) :: nonoverride3
   contains
    !ERROR: Override of NON_OVERRIDABLE 'no1' is not permitted
    procedure, nopass :: no1 => s1
  end type
  type, abstract :: missing
   contains
    procedure(s4), deferred :: am1
  end type
  !ERROR: Non-ABSTRACT extension of ABSTRACT derived type 'missing' lacks a binding for DEFERRED procedure 'am1'
  type, extends(missing) :: concrete
  end type
  type, extends(missing) :: intermediate
   contains
    procedure :: am1 => s7
  end type
  type, extends(intermediate) :: concrete2  ! ensure no false missing binding error
  end type
  !WARNING: A derived type with the BIND attribute should not be empty [-Wempty-bind-c-derived-type]
  type, bind(c) :: inextensible1
  end type
  !ERROR: The parent type is not extensible
  type, extends(inextensible1) :: badExtends1
  end type
  type :: inextensible2
    sequence
    real :: inextensible2Field
  end type
  !ERROR: The parent type is not extensible
  type, extends(inextensible2) :: badExtends2
  end type
  !ERROR: Derived type 'real' not found
  type, extends(real) :: badExtends3
  end type
  type :: base
    real :: component
   contains
    !ERROR: Procedure bound to non-ABSTRACT derived type 'base' may not be DEFERRED
    procedure(s2), deferred :: bb1
    !ERROR: DEFERRED is only allowed when an interface-name is provided
    procedure, deferred :: bb2 => s2
  end type
  type, extends(base) :: extension
   contains
     !ERROR: A type-bound procedure binding may not have the same name as a parent component
     procedure :: component => s3
  end type
  type :: nopassBase
   contains
    procedure, nopass :: tbp => s1
  end type
  type, extends(nopassBase) :: passExtends
   contains
    !ERROR: A passed-argument type-bound procedure may not override a NOPASS procedure
    procedure :: tbp => s5
  end type
  type :: passBase
   contains
    procedure :: tbp => s6
  end type
  type, extends(passBase) :: nopassExtends
   contains
    !ERROR: A NOPASS type-bound procedure may not override a passed-argument procedure
    procedure, nopass :: tbp => s1
  end type
 contains
  subroutine s1(x)
    class(abstract), intent(in) :: x
  end subroutine s1
  subroutine s2(x)
    class(base), intent(in) :: x
  end subroutine s2
  subroutine s3(x)
    class(extension), intent(in) :: x
  end subroutine s3
  subroutine s4(x)
    class(missing), intent(in) :: x
  end subroutine s4
  subroutine s5(x)
    class(passExtends), intent(in) :: x
  end subroutine s5
  subroutine s6(x)
    class(passBase), intent(in) :: x
  end subroutine s6
  subroutine s7(x)
    class(intermediate), intent(in) :: x
  end subroutine s7
end module

module m1
  implicit none
  interface g
    module procedure mp
  end interface g

  type t
  contains
    !ERROR: The binding of 'tbp' ('g') must be either an accessible module procedure or an external procedure with an explicit interface
    procedure,pass(x) :: tbp => g
  end type t

contains
  subroutine mp(x)
    class(t),intent(in) :: x
  end subroutine
end module m1

module m2
  type parent
    real realField
  contains
    !ERROR: Procedure binding 'proc' with no dummy arguments must have NOPASS attribute
    procedure proc
  end type parent
  type,extends(parent) :: child
  contains
    !ERROR: Procedure binding 'proc' with no dummy arguments must have NOPASS attribute
    procedure proc
  end type child
contains
  subroutine proc 
  end subroutine
end module m2

module m3
  type t
  contains
    procedure b
  end type
contains
  !ERROR: Cannot use an alternate return as the passed-object dummy argument
  subroutine b(*)
    return 1
  end subroutine
end module m3

module m4
  type t
  contains
    procedure b
  end type
contains
  ! Check to see that alternate returns work with default PASS arguments
  subroutine b(this, *)
    class(t) :: this
    return 1
  end subroutine
end module m4

module m5
  type t
  contains
    !ERROR: Passed-object dummy argument 'passarg' of procedure 'b' must be of type 't' but is 'INTEGER(4)'
    procedure, pass(passArg) ::  b
  end type
contains
  subroutine b(*, passArg)
    integer :: passArg
    return 1
  end subroutine
end module m5

module m6
  type t
  contains
    !ERROR: Passed-object dummy argument 'passarg' of procedure 'b' must be polymorphic because 't' is extensible
    procedure, pass(passArg) ::  b
  end type
contains
  subroutine b(*, passArg)
    type(t) :: passArg
    return 1
  end subroutine
end module m6

module m7
  type t
  contains
  ! Check to see that alternate returns work with PASS arguments
    procedure, pass(passArg) ::  b
  end type
contains
  subroutine b(*, passArg)
    class(t) :: passArg
    return 1
  end subroutine
end module m7

module m8 ! C1529 - warning only
  type t
    procedure(mysubr), pointer, nopass :: pp
   contains
    procedure, nopass :: tbp => mysubr
  end type
 contains
  subroutine mysubr
  end subroutine
  subroutine test
    type(t) a(2)
    !PORTABILITY: Base of NOPASS type-bound procedure reference should be scalar [-Wnopass-scalar-base]
    call a%tbp
    !ERROR: Base of procedure component reference must be scalar
    call a%pp
  end subroutine
end module

module m9
  type t1
   contains
    procedure, public :: tbp => sub1
  end type
  type, extends(t1) :: t2
   contains
    !ERROR: A PRIVATE procedure may not override a PUBLIC procedure
    procedure, private :: tbp => sub2
  end type
 contains
  subroutine sub1(x)
    class(t1), intent(in) :: x
  end subroutine
  subroutine sub2(x)
    class(t2), intent(in) :: x
  end subroutine
end module

module m10a
  type t1
   contains
    procedure :: tbp => sub1
  end type
 contains
  subroutine sub1(x)
    class(t1), intent(in) :: x
  end subroutine
end module
module m10b
  use m10a
  type, extends(t1) :: t2
   contains
    !ERROR: A PRIVATE procedure may not override an accessible procedure
    procedure, private :: tbp => sub2
  end type
 contains
  subroutine sub2(x)
    class(t2), intent(in) :: x
  end subroutine
end module

module m11
  type t1
   contains
    procedure, nopass :: tbp => t1p
  end type
  type, extends(t1) :: t2
   contains
    private
    !ERROR: A PRIVATE procedure may not override a PUBLIC procedure
    procedure, nopass :: tbp => t2p
  end type
 contains
  subroutine t1p
  end
  subroutine t2p
  end
end

module m12
  type t
    procedure(sub), pointer, nopass :: pp
   contains
    procedure, non_overridable, nopass :: tbp1 => sub
    procedure, nopass :: tbp2 => sub
    generic :: gen1 => tbp1
    generic :: gen2 => tbp2
  end type
 contains
  subroutine sub
  end
  subroutine test(x, y)
    class(t) :: x[*]
    type(t) :: y[*]
    call x%pp ! ok
    call y%pp ! ok
    !ERROR: Base of procedure component reference may not be coindexed
    call x[1]%pp
    !ERROR: Base of procedure component reference may not be coindexed
    call y[1]%pp
    call x%tbp1 ! ok
    call y%tbp1 ! ok
    call x[1]%tbp1 ! ok
    call y[1]%tbp1 ! ok
    call x%tbp2 ! ok
    call y%tbp2 ! ok
    !ERROR: A procedure binding may not be coindexed unless it can be resolved at compilation time
    call x[1]%tbp2
    call y[1]%tbp2 ! ok
    call x%gen1 ! ok
    call y%gen1 ! ok
    call x[1]%gen1 ! ok
    call y[1]%gen1 ! ok
    call x%gen2 ! ok
    call y%gen2 ! ok
    !ERROR: A procedure binding may not be coindexed unless it can be resolved at compilation time
    call x[1]%gen2
    call y[1]%gen2 ! ok
  end
end

program test
  use m1
  type,extends(t) :: t2
  end type
  type(t2) a
  call a%tbp
end program
