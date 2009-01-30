<?xml version="1.0" encoding="UTF-8"?>
<!-- XSL to take a freemind file (mm) and convert it to generic XML to be used by METAFOR -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/02/xpath-functions"
  xmlns:xdt="http://www.w3.org/2005/02/xpath-datatypes">

  <!-- output an XML file -->
  <xsl:output method="xml" indent="yes"/>

  <!-- ignore free text and comments -->
  <xsl:template match="text()"/>
  <xsl:template match="comment()"/>

  <!-- top-level template -->
  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- match each node -->
  <xsl:template match="node">
    <xsl:variable name="depth" select="count(ancestor::node)"/>
    <xsl:choose>
      <!-- a node is either the root node... -->
      <xsl:when test="$depth=0">
        <xsl:element name="root">
          <xsl:comment>
            <xsl:value-of select="concat(' ',@TEXT,' ')"/>
          </xsl:comment>
          <xsl:apply-templates/>
        </xsl:element>
      </xsl:when>
      <!-- a branch node... -->
      <xsl:when test="descendant::node">
        <xsl:call-template name="branch"/>
      </xsl:when>
      <!-- or a leaf node -->
      <xsl:otherwise>
        <xsl:call-template name="leaf"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- the branch template -->
  <xsl:template name="branch">
    <xsl:element name="branch">
      <xsl:copy-of select="@TEXT"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- the leaf template -->
  <xsl:template name="leaf">
    <xsl:element name="leaf">
      <xsl:copy-of select="@TEXT"/>
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>

  <!-- nodes can have constraints (tagged as icons) associated with them -->
  <xsl:template match="icon">
    <xsl:variable name="type" select="@BUILTIN"/>
    <xsl:choose>
      <xsl:when test="$type='button_ok'"> <!-- checkmark icon -->
        <xsl:attribute name="type">
          <xsl:text>OR</xsl:text>
        </xsl:attribute>
      </xsl:when>
      <xsl:when test="$type='button_cancel'"> <!-- cross icon -->
        <xsl:attribute name="type">
          <xsl:text>XOR</xsl:text>
        </xsl:attribute>
      </xsl:when>
      <xsl:when test="$type='bookmark'"> <!-- star icon -->
        <xsl:attribute name="type">
          <xsl:text>AND</xsl:text>
        </xsl:attribute>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
