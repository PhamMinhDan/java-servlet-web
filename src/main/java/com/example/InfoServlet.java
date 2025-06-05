package com.example;

import java.io.*;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import jakarta.servlet.annotation.WebServlet;

@WebServlet("/info")
public class InfoServlet extends HttpServlet {
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.setContentType("text/html");
        PrintWriter out = response.getWriter();
        out.println("<h2>Thông tin nhóm:</h2>");
        out.println("<ul>");
        out.println("<li>Nguyễn Văn A - MSSV: 123</li>");
        out.println("<li>Trần Thị B - MSSV: 456</li>");
        out.println("<li>Lê Văn C - MSSV: 789</li>");
        out.println("</ul>");
    }
}
