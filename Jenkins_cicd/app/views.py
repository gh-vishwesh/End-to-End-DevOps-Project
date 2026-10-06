from django.shortcuts import render, redirect, get_object_or_404
from django.views.decorators.http import require_POST
from .models import register
# Create your views here.
def Insertpage(request):
    return render(request,"insert.html")

@require_POST
def Insertdata(request):
    #Data come from html view
    fname=request.POST['fname']
    lname=request.POST['lname']
    mail=request.POST['mail']
    phone=request.POST['phone']

    #Creating object of the model Class
    #inserting data into the table
    register.objects.create(Firstname=fname,Lastname=lname,Email=mail,Contact=phone)

    #After insert render on show.html
    return redirect(Showpage) 

def Showpage(request):
    #select * from table
    all_data=register.objects.all()
    return render(request,"show.html",{'key1':all_data})

def Editpage(request,pk):
    #fetching the data of particular ID
    get_data=get_object_or_404(register,id=pk)
    return render(request,"edit.html",{'key2':get_data})

@require_POST
def Update(request,pk):
    updatedata=get_object_or_404(register,id=pk)
    updatedata.Firstname=request.POST['fname']
    updatedata.Lastname=request.POST['lname']
    updatedata.Email=request.POST['mail']
    updatedata.Contact=request.POST['phone']
    #query for save
    updatedata.save()
    return redirect(Showpage) 

@require_POST
def Delete(request,pk):
    deletedata=get_object_or_404(register,id=pk)
    #quere for delete
    deletedata.delete()
    return redirect(Showpage) 
